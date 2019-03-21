defmodule Events do
  @moduledoc false

  use GenServer

  def init(state) do
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
