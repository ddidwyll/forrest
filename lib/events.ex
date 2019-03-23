require Logger

defmodule Events do
  @moduledoc false

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
    Logger.info("Events module started")
    {:ok, state}
  end

  def start_link(state \\ []) do
    GenServer.start_link(
      __MODULE__,
      state,
      name: :events
    )
  end

  def handle_info(:garbage, state) do
    Events.Store.garbage()
    Logger.info("Events garbage collected")
    send_after(:events, :garbage, 3_600_000)
    {:noreply, state}
  end

  def handle_cast({:subscribe, conn}, state) do
    Logger.info("Events subscribers connected")
    {:noreply, [conn | state]}
  end

  def handle_cast({:event, msg}, state) do
    Logger.info("Events cast: #{msg}")
    alive =
      for conn <- state, alive?(conn) do
        send(conn, {:event, msg})
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

  def info({:event, msg}, req, state) do
    event = %{
      event: "message",
      data: msg
    }

    Request.stream_events(event, :nofin, req)
    {:ok, req, state, :hibernate}
  end
end

defmodule Events.Store do
  @moduledoc false

  alias :mnesia, as: Mnesia

  @db :events
  @ids_list [:"$1"]
  @all_fields [:"$$"]
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

  defp select(matcher, fiels \\ @all_fields) do
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

  def history(id) do
    [{:==, :"$4", id}]
    |> select()
  end

  def garbage() do
    week_ago = now() - 7 * 24 * 60 * 60 * 1000

    fn ->
      Mnesia.select(
        @db,
        [{@db_struct, [{:<, :"$1", week_ago}], @ids_list}]
      )
      |> Enum.each(&Mnesia.delete({@db, &1}))
    end
    |> Mnesia.transaction()
  end
end
