defmodule Forrest.History do
  @moduledoc false

  use GenServer
  import Plug.Conn

  def init(state) do
    {:ok, state}
  end

  def start_link(state \\ []) do
    GenServer.start_link(__MODULE__, state, name: History)
  end

  def handle_call({:add, conn}, _, state) do
    conn = connect(conn)
    IO.inspect(last_id(conn))
    {:reply, conn, [conn | state]}
  end

  def handle_cast({:message, message}, state) do
    for conn <- state do
      conn |> chunk("data: #{message}\n\n")
    end

    {:noreply, state}
  end

  defp each_conn(state, fun) when is_list(state) do
    for conn <- state do
      conn |> fun
    end
  end

  defp now() do
    :os.system_time(:millisecond)
  end

  defp send_message(conn, id) do
    chunk(conn, "id: #{id}\nretry: 1000\nevent: \"message\"\n\ndata: #{id}\n\n")
  end

  defp send_time(conn, state \\ 0) do
    send_message(conn, state)
    :timer.sleep(1000)
    state = state + 1
    send_time(conn, state)
  end

  def last_id(conn) do
    case get_req_header(conn, "last-event-id") do
      [id | _] -> String.to_integer(id)
      _ -> nil
    end
  end

  def connect(conn) do
    conn
    |> put_resp_header("content-type", "text/event-stream")
    |> put_resp_header("cache-control", "no-cache")
    |> put_resp_header("connection", "keep-alive")
    |> send_chunked(200)
  end
end
