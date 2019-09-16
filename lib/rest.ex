defmodule Tree.Rest do
  @moduledoc false

  @behaviour :cowboy_rest

  use Tree.RestBuilder

  import :erlang,
    only: [posixtime_to_universaltime: 1]

  import String, only: [slice: 3, to_integer: 1]
  import Tree.Main

  @methods [
    "OPTIONS",
    "DELETE",
    "POST",
    "GET",
    "PUT"
  ]

  @application_json {
    "application",
    "json",
    :*
  }

  @to_json {
    @application_json,
    :to_json
  }

  @from_json {
    @application_json,
    :from_json
  }

  @impl true
  def content_types_provided(req, state) do
    {[@to_json], req, state}
  end

  @impl true
  def content_types_accepted(req, state) do
    {[@from_json], req, state}
  end

  @impl true
  def allowed_methods(req, state) do
    {@methods, req, state}
  end

  @impl true
  def delete_completed(req, state) do
    {true, req, state}
  end

  @impl true
  def delete_resource(req, state) do
    delete({req, state})
  end

  @impl true
  def expires(req, state) do
    {:undefined, req, state}
  end

  @impl true
  def resource_exists(req, state) do
    exist(req, state)
  end

  @impl true
  def previously_existed(req, state0) do
    state = status(state0)

    {!!state.out, req, state}
    |> message()
  end

  @impl true
  def moved_permanently(req, state) do
    {state.to || false, req, state}
  end

  @impl true
  def rate_limited(req, state) do
    {false, req, state}
  end

  @impl true
  def generate_etag(req, state) do
    {{:weak, state.upd}, req, state}
  end

  @impl true
  def last_modified(req, state) do
    last_mod =
      state.upd
      |> slice(0, 10)
      |> to_integer()
      |> posixtime_to_universaltime()

    {last_mod, req, state}
  end

  @impl true
  def forbidden(req, state) do
    {false, req, state}
  end

  def to_json(req, state) do
    {state.out, req, state}
  end

  def from_json(req, state) do
    case req.method do
      "POST" -> post(req, state)
    end
  end
end
