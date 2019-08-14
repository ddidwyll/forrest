defmodule Tree.Events do
  @moduledoc false

  use GenServer
  alias Tree.Events.Store

  import Process,
    only: [alive?: 1, send_after: 3]

  import GenServer,
    only: [cast: 2, call: 2, start_link: 3]

  import Enum,
    only: [uniq: 1, find_value: 3]

  @struct [:time, :branch, :id, :action]

  def start_link(_) do
    start_link(
      __MODULE__,
      nil,
      name: :events
    )
  end

  @impl true
  def init(_) do
    :mnesia.create_table(
      :events,
      [
        {:disc_copies, [node()]},
        {:type, :ordered_set},
        {:attributes, @struct}
      ]
    )

    send_after(:events, :garbage, 60_000)
    {:ok, []}
  end

  @impl true
  def handle_cast({:subscribe, conn}, state) do
    {pid, user, last_id} = conn

    for event <- Store.get(last_id) do
      send(pid, {:event, event})
    end

    {:noreply, [{pid, user} | state]}
  end

  @impl true
  def handle_cast({:event, branch, id, action, t}, state) do
    {:ok, time} = Store.put(branch, id, action, t)

    alive =
      for {pid, _} = conn <- state, alive?(pid) do
        send(pid, {:event, [time, branch, id, action]})
        conn
      end

    {:noreply, alive}
  end

  @impl true
  def handle_call(:online, _, state) do
    users = for {_, user} <- state, do: user
    {:reply, uniq(users), state}
  end

  def subscribe(pid, user, last_id),
    do: cast(:events, {:subscribe, {pid, user, last_id}})

  def event(branch, id, action, time),
    do: cast(:events, {:event, branch, id, action, time})

  def online(), do: call(:events, :online)
  def online(id), do: id in online()

  @impl true
  def handle_info(:garbage, state) do
    Store.garbage()
    send_after(:events, :garbage, 3_600_000)
    {:noreply, state}
  end
end

defmodule Tree.Events.Stream do
  @moduledoc false

  @behaviour :cowboy_loop

  import :cowboy_req,
    only: [stream_reply: 3, stream_events: 3]

  import Tree.Events, only: [subscribe: 3]

  @headers %{
    "content-type" => "text/event-stream",
    "cache-control" => "no-cache",
    "connection" => "keep-alive",
    "access-control-allow-origin" => "*"
  }

  @impl true
  def init(req0, state) do
    user = req0.bindings[:user]
    last_id = last_id(req0) || ""
    subscribe(self(), user, last_id)
    req = stream_reply(200, @headers, req0)
    {:cowboy_loop, req, state, :hibernate}
  end

  @impl true
  def info({:event, data}, req, state) do
    [time, branch, id, action] = data

    event = %{
      id: time,
      data:
        "{\"id\":\"#{id}\",\"branch\":\"#{branch}\"," <>
          "\"action\":\"#{action}\",\"time\":\"#{time}\"}"
    }

    stream_events(event, :nofin, req)
    {:ok, req, state, :hibernate}
  end

  defp last_id(req) do
    req.headers["last-event-id"] || req.bindings[:last_id]
  end
end

defmodule Tree.Events.Store do
  @moduledoc false

  alias :mnesia, as: Mnesia
  import Enum, only: [each: 2]

  @db :events
  @ids [:"$1"]
  @all [:"$$"]
  @db_struct {@db, :"$1", :"$2", :"$3", :"$4"}

  defp now do
    :os.system_time(:millisecond)
  end

  def put(branch, id, action, t \\ nil) do
    time = t || now() |> to_string

    fun = fn ->
      {@db, time, branch, id, action}
      |> Mnesia.write()
    end

    case Mnesia.transaction(fun) do
      {:atomic, :ok} -> {:ok, time}
      _ -> :error
    end
  end

  defp select(matcher, fields \\ @all) do
    {:atomic, result} =
      fn ->
        Mnesia.select(
          @db,
          [{@db_struct, matcher, fields}]
        )
      end
      |> Mnesia.transaction()

    result
  end

  def get(from \\ "") do
    [{:>, :"$1", from}]
    |> select()
  end

  def garbage() do
    day_ago =
      (now() - 30 * 24 * 60 * 60 * 1000)
      |> to_string

    fn ->
      Mnesia.select(
        @db,
        [{@db_struct, [{:<, :"$1", day_ago}], @ids}]
      )
      |> each(&Mnesia.delete({@db, &1}))
    end
    |> Mnesia.transaction()
  end
end

defmodule Tree.Events.Route do
  @moduledoc false

  @behaviour :cowboy_handler

  @headers %{
    "content-type" => "application/json",
    "access-control-allow-origin" => "*"
  }

  import Tree.Events.Store, only: [get: 1]
  import :cowboy_req, only: [reply: 4]
  import Enum, only: [join: 2]

  @impl true
  def init(req0, state) do
    events =
      for event <- get(req0.bindings[:last_id]) do
        [time, branch, id, action] = event

        "{\"id\":\"#{id}\",\"branch\":\"#{branch}\"," <>
          "\"action\":\"#{action}\",\"time\":#{time}}"
      end
      |> join(",")

    req = reply(200, @headers, "[" <> events <> "]", req0)
    {:ok, req, state}
  end
end
