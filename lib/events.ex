defmodule Events do
  @moduledoc false

  use GenServer

  def init(state) do
    :mnesia.create_table(
      Events,
      attributes: [
        :time,
        :action,
        :branch,
        :id
      ]
    )

    {:ok, state}
  end

  def start_link(state \\ []) do
    GenServer.start_link(
      __MODULE__,
      state,
      name: Events
    )
  end

  def handle_cast({:add, conn}, state) do
    {:noreply, [conn | state]}
  end

  def handle_cast({:message, msg}, state) do
    alive =
      for conn <- state, Process.alive?(conn) do
        send(conn, {:message, msg})
        conn
      end

    {:noreply, alive}
  end

  def subscribe(pid), do: GenServer.cast(Events, {:add, pid})
  def cast(text), do: GenServer.cast(Events, {:message, text})
end

defmodule Events.Route do
  @moduledoc false

  alias :cowboy_req, as: Request

  def init(req0, state) do
    req =
      Request.stream_reply(
        200,
        %{
          "content-type" => "text/event-stream",
          "cache-control" => "no-cache",
          "connection" => "keep-alive"
        },
        req0
      )

    Events.subscribe(self())
    {:cowboy_loop, req, state, :hibernate}
  end

  def info({:message, msg}, req, state) do
    Request.stream_events(
      %{
        event: "message",
        data: msg
      },
      :nofin,
      req
    )

    {:ok, req, state, :hibernate}
  end
end

defmodule Events.Store do
  @moduledoc false

  @db Events
  alias :mnesia, as: Mnesia

  def put(action, branch, id) do
    time = :os.system_time(:millisecond)
    event = {@db, time, action, branch, id}

    case fn -> Mnesia.write(event) end
         |> Mnesia.transaction() do
      {:atomic, :ok} -> {:ok, time}
      _ -> :error
    end
  end

  def get(from \\ 0) do
    # week_ago = 7 * 24 * 60 * 60 * 1000

    fn ->
      Mnesia.select(
        @db,
        [
          {
            {@db, :"$1", :"$2", :"$3", :"$4"},
            [{:>, :"$1", from}],
            [:"$$"]
          }
        ]
      )
    end
    |> Mnesia.transaction()
  end

  # def get(id) do
  #   case @db |> Dets.lookup(id) do
  #     [{_, :active, json} | _] -> {:ok, json}
  #     _ -> {:error, "\"User not exists or blocked\""}
  #   end
  # end

  # def put(user) do
  #   case to_json(user) do
  #     {:ok, json} -> @db |> Dets.insert({user["id"], :active, json})
  #     _ -> :error
  #   end
  # end
end
