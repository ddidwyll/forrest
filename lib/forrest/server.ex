defmodule Forrest.Server do
  @moduledoc false

  use Plug.Router

  plug(:match)
  plug(:dispatch)

  get "/sse" do
    conn = GenServer.call(History, {:add, conn})
    # IO.inspect(conn.adapter)
    :timer.sleep(1_000_000_000)
    conn
  end

  forward("/auth", to: Forrest.Auth.Plug)

  match _ do
    send_resp(conn, 404, "Not found.")
  end
end
