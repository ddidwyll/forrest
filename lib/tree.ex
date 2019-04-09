defmodule Tree do
  @moduledoc false

  @branch [:id, :uid, :gid, :status, :upd, :json]
  @bag [:id, :uid, :gid, :status, :json]
  @rel [:left, :right, :uid, :gid, :status, :json]

  def init() do
    table(:tree, :set, @branch)
    table(:rels, :bag, @rel)
    table(:bag, :bag, @bag)
  end

  defp table(name, type, attrs) do
    :mnesia.create_table(
      name,
      [
        {:disc_copies, [node()]},
        {:attributes, attrs},
        {:type, type}
      ]
    )
  end
end

defmodule Tree.Route do
  @moduledoc false

  @behaviour :cowboy_rest

  import :cowboy_req,
    only: [
      set_resp_headers: 2,
      set_resp_body: 2
    ]

  import Config, only: [schema: 1]
  import Logger, only: [info: 1]

  @methods [
    "OPTIONS",
    "DELETE",
    "PATCH",
    "POST",
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

  @from_json {
    @application_json,
    :from_json
  }

  @utf8 "utf-8"

  @headers %{
    "github" => "ddidwyll/forrest",
    "server" => "forrest"
  }

  @impl true
  def init(req0, opts) do
    req = set_resp_headers(@headers, req0)

    state = %{
      schema: schema(req.bindings.branch),
      branch: req.bindings.branch,
      type: req.bindings.type,
      id: req.bindings[:id],
      method: req.method,
      input: "empty",
      opts: opts,
      list: []
    }

    info("init, #{inspect(state)}")
    {:cowboy_rest, req, state}
  end

  @impl true
  def content_types_provided(req, state) do
    info("content_types_provided")
    {[@to_json], req, state}
  end

  @impl true
  def content_types_accepted(req, state) do
    info("content_types_accepted")
    {[@from_json], req, state}
  end

  @impl true
  def allowed_methods(req, state) do
    info("allowed_methods")
    {@methods, req, state}
  end

  @impl true
  def charsets_provided(req, state) do
    info("charsets_provided")
    {[@utf8], req, state}
  end

  @impl true
  def delete_completed(req, state) do
    info("delete_completed")
    {false, req, state}
  end

  @impl true
  def delete_resource(req, state) do
    info("delete_resource")
    {false, req, state}
  end

  @impl true
  def forbidden(req, state) do
    info("forbidden")
    {false, req, state}
  end

  @impl true
  def malformed_request(req, state) do
    cond do
      state.type not in ["tree", "bag", "rels"] ->
        message = "\"Wrong type #{state.type}\""
        {true, set_resp_body(message, req), state}

      !state.schema ->
        message = "\"Wrong branch #{state.branch}\""
        {true, set_resp_body(message, req), state}

      true ->
        {false, req, state}
    end
  end

  # @impl true
  # def options(req0, state) do
  #   info("options")
  #   json = Jason.encode!(state.schema)
  #   req = reply(200, @headers, json, req0)
  #   {:ok, req, state}
  # end

  def to_json(req, state) do
    info("to_json, #{inspect(state.list)}")
    json = "[" <> Enum.join(state.list, ",") <> "]"
    {json, req, state}
  end

  def from_json(req0, state) do
    info("from_json, #{inspect(state.input)}")
    req = set_resp_body(state.input, req0)
    {true, req, state}
  end
end

defmodule Tree.JSON do
  @moduledoc false

  def to_json(req, state) do
    {"json", req, state}
  end

  def from_json(req, state) do
    {true, req, state}
  end
end

defmodule Tree.Store do
  # @moduledoc false

  # alias :mnesia, as: Mnesia
  # import Enum, only: [each: 2]

  # @db :tree
  # @ids [:"$1"]
  # @all [:"$$"]
  # @db_struct {@db, :"$1", :"$2", :"$3", :"$4"}

  # defp now do
  #   :os.system_time(:millisecond)
  # end

  # def put(action, branch, id) do
  #   time = now() |> to_string

  #   fun = fn ->
  #     {@db, time, action, branch, id}
  #     |> Mnesia.write()
  #   end

  #   case Mnesia.transaction(fun) do
  #     {:atomic, :ok} -> {:ok, time}
  #     _ -> :error
  #   end
  # end

  # defp select(matcher, fields \\ @all) do
  #   {:atomic, result} =
  #     fn ->
  #       Mnesia.select(
  #         @db,
  #         [{@db_struct, matcher, fields}]
  #       )
  #     end
  #     |> Mnesia.transaction()

  #   result
  # end

  # def get(from \\ "") do
  #   [{:>, :"$1", from}]
  #   |> select()
  # end

  # def garbage() do
  #   day_ago =
  #     (now() - 24 * 60 * 60 * 1000)
  #     |> to_string()

  #   fn ->
  #     Mnesia.select(
  #       @db,
  #       [{@db_struct, [{:<, :"$1", day_ago}], @ids}]
  #     )
  #     |> each(&Mnesia.delete({@db, &1}))
  #   end
  #   |> Mnesia.transaction()
  # end
end
