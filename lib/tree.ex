defmodule Tree do
  @moduledoc false

  @branch [:id, :uid, :gid, :status, :upd, :json]
  @other [:id, :uid, :gid, :status, :json]
  @rel [:left, :right, :uid, :gid, :status, :json]

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

  def init() do
    table(:tree, :set, @branch)
    table(:bag, :bag, @other)
    table(:rels, :bag, @rel)
  end
end

defmodule Tree.Route do
  @moduledoc false

  import :cowboy_req,
    only: [reply: 4, set_resp_body: 2]

  import Config, only: [schema: 1]
  import Logger, only: [info: 1]

  @methods [
    "OPTIONS",
    "POST",
    "PATCH",
    "GET",
    "DELETE"
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
    "server" => "forrest",
    "github" => "ddidwyll/forrest"
  }

  def init(req, opts) do
    state = %{
      method: req.method,
      schema: schema(req.bindings.branch),
      id: req.bindings[:id],
      opts: opts,
      output: [],
      input: "empty"
    }

    info("init, #{inspect(state)}")
    {:cowboy_rest, req, state}
  end

  def content_types_provided(req, state) do
    info("content_types_provided, #{inspect(state.opts)}")
    {[@to_json], req, state}
  end

  def content_types_accepted(req, state) do
    info("content_types_accepted, #{inspect(state.opts)}")
    {[@from_json], req, state}
  end

  def allowed_methods(req, state) do
    info("allowed_methods, #{inspect(state.opts)}")
    {@methods, req, state}
  end

  def charsets_provided(req, state) do
    info("charsets_provided, #{inspect(state.opts)}")
    {[@utf8], req, state}
  end

  def delete_completed(req, state) do
    info("delete_completed, #{inspect(state.opts)}")
    {false, req, state}
  end

  def delete_resource(req, state) do
    info("delete_resource, #{inspect(state.opts)}")
    {false, req, state}
  end

  def forbidden(req, state) do
    info("forbidden, #{inspect(state.opts)}")
    {false, req, state}
  end

  def malformed_request(req0, state) do
    info("malformed_request, #{inspect(state.opts)}")

    req =
      if !state.schema do
        set_resp_body("\"Branch not exists\"", req0)
      else
        req0
      end

    {!state.schema, req, state}
  end

  def to_json(req, state) do
    info("to_json, #{inspect(state.output)}")
    json = "[" <> Enum.join(state.output, ",") <> "]"
    {json, req, state}
  end

  def from_json(req0, state) do
    info("from_json, #{inspect(state.input)}")
    req = set_resp_body(state.input, req0)
    {true, req, state}
  end

  def options(req0, state) do
    info("options")
    json = Jason.encode!(state.schema)
    req = reply(200, @headers, json, req0)
    {:ok, req, state}
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
