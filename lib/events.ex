defmodule Events do
  @moduledoc false

  require Logger
  use GenServer
  import GenServer, only: [cast: 2]
  import Process, only: [alive?: 1, send_after: 3]

  @event [:time, :action, :branch, :id, :prev]

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

  def start_link(state \\ []) do
    GenServer.start_link(
      __MODULE__,
      state,
      name: :events
    )
  end

  def handle_cast({:subscribe, conn}, state) do
    {pid, user, last_id} = conn

    for event <- Events.Store.get(last_id) do
      send(pid, {:event, event})
    end

    {:noreply, [{pid, user} | state]}
  end

  def handle_cast({:event, event}, state) do
    alive =
      for {pid, _} = conn <- state, alive?(pid) do
        send(pid, {:event, event})
        conn
      end

    {:noreply, alive}
  end

  def handle_call(:online, _, state) do
    users = for {_, user} <- state, do: user
    {:reply, Enum.uniq(users), state}
  end

  def subscribe(conn),
    do: cast(:events, {:subscribe, conn})

  def event(event),
    do: cast(:events, {:event, event})

  def handle_info(:garbage, state) do
    Events.Store.garbage()
    send_after(:events, :garbage, 3_600_000)
    {:noreply, state}
  end
end

defmodule Events.Route do
  @moduledoc false

  alias :cowboy_req, as: Request

  def init(req0, state) do
    headers = %{
      "content-type" => "text/event-stream",
      "cache-control" => "no-cache",
      "connection" => "keep-alive"
    }

    user = req0.bindings[:user]
    last_id = last_id(req0) || 0
    Events.subscribe({self(), user, last_id})
    req = Request.stream_reply(200, headers, req0)
    {:cowboy_loop, req, state, :hibernate}
  end

  def info({:event, data}, req, state) do
    [time, action, branch, id, _] = data

    event = %{
      id: "#{time}",
      event: action,
      data: "#{id}@#{branch}"
    }

    Request.stream_events(event, :nofin, req)
    {:ok, req, state, :hibernate}
  end

  defp last_id(req) do
    (req.headers["last-event-id"] || req.bindings[:last_id] || "0")
    |> String.to_integer()
  end
end

defmodule Events.Store do
  @moduledoc false

  alias :mnesia, as: Mnesia

  @db :events
  @ids [:"$1"]
  @all [:"$$"]
  @db_struct {@db, :"$1", :"$2", :"$3", :"$4", :"$5"}

  defp now do
    :os.system_time(:millisecond)
  end

  def put(action, branch, id) do
    time = now()

    fun = fn ->
      prev = Mnesia.last(@db)

      {@db, time, action, branch, id, prev}
      |> Mnesia.write()
    end

    case Mnesia.transaction(fun) do
      {:atomic, :ok} -> {:ok, time}
      _ -> :error
    end
  end

  defp select(matcher, fiels \\ @all) do
    {:atomic, result} =
      fn ->
        Mnesia.select(
          @db,
          [{@db_struct, matcher, fiels}]
        )
      end
      |> Mnesia.transaction()

    result
  end

  def get(from \\ 0) do
    [{:>, :"$1", from}]
    |> select()
  end

  def garbage() do
    week_ago = now() - 7 * 24 * 60 * 60 * 1000

    fn ->
      Mnesia.select(
        @db,
        [{@db_struct, [{:<, :"$1", week_ago}], @ids}]
      )
      |> Enum.each(&Mnesia.delete({@db, &1}))
    end
    |> Mnesia.transaction()
  end
end
