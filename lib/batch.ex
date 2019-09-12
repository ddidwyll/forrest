defmodule Tree.Batch do
  @moduledoc false

  @behaviour :cowboy_rest

  use Tree.RestBuilder

  import Tree.Store

  @methods [
    "OPTIONS",
    "GET"
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

  @impl true
  def allowed_methods(req, state) do
    {@methods, req, state}
  end

  def to_json(req, state) do
    json =
      cond do
        state.to == "user" && !is_nil(state.from) ->
          get_by_user(state.schema["type"], state.branch, state.from)
          |> list_json
          |> to_json

        state.to == "group" && !is_nil(state.from) ->
          get_by_group(state.schema["type"], state.branch, state.from)
          |> list_json
          |> to_json

        true ->
          get_all(state.schema["type"], state.branch, :active, :_, :_)
          |> list_json
          |> to_json
      end

    {json, req, state}
  end

  @impl true
  def content_types_provided(req, state) do
    {[@to_json], req, state}
  end
end
