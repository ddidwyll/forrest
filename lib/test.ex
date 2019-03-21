defmodule Eventsourse do
  alias :cowboy_req, as: Request

  def init(req, state) do
    handle(req, state)
  end

  def handle(request, state) do
    req =
      Request.stream_reply(
        200,
        %{
          "content-type" => "text/event-stream"
        },
        request
      )

    {:cowboy_loop, req, state, :hibernate}
  end

  def info({:message, msg}, req, state) do
    Request.stream_events(
      %{
        id: id(),
        data: msg
      },
      :nofin,
      req
    )

    {:ok, req, state, :hibernate}
  end

  def info(:long, _req, _state) do
    {:set_options, %{idle_timeout: 10000}}
  end

  def info(value, req, state) do
    {:ok, req, state, :hibernate}
  end

  def terminate(reason, _, _) do
    :ok
  end

  defp id() do
    :erlang.unique_integer([:positive, :monotonic])
    |> Integer.to_string()
  end
end
