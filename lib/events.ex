defmodule Events do
  @moduledoc false

  use GenServer
  alias Events.Store

  import Process,
    only: [alive?: 1, send_after: 3]

  import GenServer,
    only: [cast: 2, call: 2, start_link: 3]

  import Enum,
    only: [uniq: 1, find_value: 3]

  @event [:time, :action, :branch, :id]

  def init(state) do
    :mnesia.create_table(
      :events,
      [
        {:disc_copies, [node()]},
        {:type, :ordered_set},
        {:attributes, @event}
      ]
    )

    send_after(:events, :garbage, 60_000)
    {:ok, state}
  end

  def start_link() do
    start_link(
      __MODULE__,
      [],
      name: :events
    )
  end

  def handle_cast({:subscribe, conn}, state) do
    {pid, user, last_id} = conn

    for event <- Store.get(last_id) do
      send(pid, {:event, event})
    end

    {:noreply, [{pid, user} | state]}
  end

  def handle_call({:event, action, branch, id}, _, state) do
    {:ok, time} = Store.put(action, branch, id)

    alive =
      for {pid, _} = conn <- state, alive?(pid) do
        send(pid, {:event, [time, action, branch, id]})
        conn
      end

    {:reply, time, alive}
  end

  def handle_call(:online, _, state) do
    users = for {_, user} <- state, do: user
    {:reply, uniq(users), state}
  end

  def subscribe(pid, user, last_id),
    do: cast(:events, {:subscribe, {pid, user, last_id}})

  def new(action, branch, id),
    do: call(:events, {:event, action, branch, id})

  def online(), do: call(:events, :online)

  def online(id),
    do: online() |> find_value(false, &(&1 === id))

  def handle_info(:garbage, state) do
    Store.garbage()
    send_after(:events, :garbage, 3_600_000)
    {:noreply, state}
  end
end

defmodule Events.Route do
  @moduledoc false

  import :cowboy_req,
    only: [stream_reply: 3, stream_events: 3]

  import Events,
    only: [subscribe: 3]

  def init(req0, state) do
    headers = %{
      "content-type" => "text/event-stream",
      "cache-control" => "no-cache",
      "connection" => "keep-alive"
    }

    user = req0.bindings[:user]
    last_id = last_id(req0) || ""
    subscribe(self(), user, last_id)
    req = stream_reply(200, headers, req0)
    {:cowboy_loop, req, state, :hibernate}
  end

  def info({:event, data}, req, state) do
    [time, action, branch, id] = data

    event = %{
      id: time,
      event: action,
      data: "#{id}@#{branch}"
    }

    stream_events(event, :nofin, req)
    {:ok, req, state, :hibernate}
  end

  defp last_id(req) do
    req.headers["last-event-id"] || req.bindings[:last_id]
  end
end

defmodule Events.Store do
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

  def put(action, branch, id) do
    time = now() |> to_string

    fun = fn ->
      {@db, time, action, branch, id}
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

  def subscribers(current) do
    prev =
      [{:==, :"$2", "online"}]
      |> select()

  end

  def garbage() do
    day_ago =
      (now() - 24 * 60 * 60 * 1000)
      |> to_string()

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
