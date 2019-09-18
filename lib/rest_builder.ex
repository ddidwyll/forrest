defmodule Tree.RestBuilder do
  @moduledoc false

  @behaviour :cowboy_rest

  defmacro __using__(_) do
    alias Tree.RestBuilder, as: RB

    # defdelegate options(r, s), to: RB
    quote do
      defdelegate init(r, s), to: RB
      defdelegate malformed_request(r, s), to: RB
      defdelegate charsets_provided(r, s), to: RB
      defdelegate is_authorized(r, s), to: RB
    end
  end

  import :cowboy_req,
    only: [
      set_resp_headers: 2,
      set_resp_body: 2
    ]

  import Tree.Config, only: [schema: 1]

  @headers %{
    "github" => "ddidwyll/forrest",
    "server" => "forrest",
    "access-control-allow-origin" => "*",
    "access-control-allow-headers" =>
      "Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With"
  }

  @headers_preflight %{
    "access-control-allow-headers" =>
      "Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With"
  }

  @utf8 "utf-8"

  @impl true
  def init(req0, _) do
    state = %{
      schema: schema(req0.bindings.branch),
      branch: req0.bindings.branch,
      from: req0.bindings[:from],
      to: req0.bindings[:to],
      uid: "ddidwyll",
      gid: "work",
      upd: nil,
      out: nil,
      in: nil
    }

    req = set_resp_headers(@headers, req0)
    {:cowboy_rest, req, state}
  end

  @impl true
  def options(req0, state) do
    req = set_resp_headers(@headers_preflight, req0)
    {:ok, req, state}
  end

  @impl true
  def malformed_request(req, state) do
    cond do
      !state.schema ->
        message = "\"Wrong branch #{state.branch}\""
        {true, set_resp_body(message, req), state}

      true ->
        {false, req, state}
    end
  end

  @impl true
  def charsets_provided(req, state) do
    {[@utf8], req, state}
  end

  @impl true
  def is_authorized(req, state) do
    {{a, b, c, d}, _} = req.peer
    IO.puts("#{a}.#{b}.#{c}.#{d}")
    {true, req, state}
  end
end
