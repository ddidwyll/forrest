defmodule Events do
  @moduledoc false

  use GenServer
  import GenServer, only: [cast: 2]
  import Process, only: [alive?: 1]

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

    {:ok, state}
  end

  def start_link(state) do
    GenServer.start_link(
      __MODULE__,
      state,
      name: :events
    )
  end

  def handle_cast({:subscribe, conn}, state) do
    {:noreply, [conn | state]}
  end

  def handle_cast({:message, msg}, state) do
    alive =
      for conn <- state, alive?(conn) do
        send(conn, {:message, msg})
        conn
      end

    {:noreply, alive}
  end

  def subscribe(pid), do: cast(:events, {:subscribe, pid})
  def cast(text), do: cast(:events, {:message, text})
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

    Events.subscribe(self())
    req = Request.stream_reply(200, headers, req0)
    {:cowboy_loop, req, state, :hibernate}
  end

  def info({:message, msg}, req, state) do
    event = %{
      event: "message",
      data: msg
    }

    Request.stream_events(event, :nofin, req)
    {:ok, req, state, :hibernate}
  end
end

# week_ago = 7 * 24 * 60 * 60 * 1000

defmodule Events.Store do
  @moduledoc false

  @db :events
  @all_fields [:"$$"]
  @db_struct {@db, :"$1", :"$2", :"$3", :"$4", :"$5"}
  alias :mnesia, as: Mnesia

  def put(action, branch, id) do
    time = :os.system_time(:millisecond)

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

  def get(from \\ 0) do
    {:atomic, result} =
      fn ->
        Mnesia.select(
          @db,
          [{@db_struct, [{:>, :"$1", from}], @all_fields}]
        )
      end
      |> Mnesia.transaction()

    result
  end
end
