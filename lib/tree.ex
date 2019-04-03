defmodule Tree do
  @moduledoc false

  @branch [
    :id,
    :uid,
    :gid,
    :status,
    :upd,
    :json
  ]

  def init() do
    :mnesia.create_table(
      :tree,
      [
        {:disc_copies, [node()]},
        {:type, :set},
        {:attributes, @branch}
      ]
    )

    :mnesia.create_table(
      :bag,
      [
        {:disc_copies, [node()]},
        {:type, :bag},
        {:attributes, @branch}
      ]
    )
  end
end

defmodule Tree.Route do
  @moduledoc false

  import :cowboy_req,
    only: [reply: 4, set_resp_body: 2]

  import Forrest
  require Logger

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
      schema: schema(req.bindings.branch),
      id: req.bindings[:id],
      opts: opts,
      output: [],
      input: "empty"
    }

    Logger.info("init, #{inspect(state.opts)}")
    {:cowboy_rest, req, state}
  end

  def content_types_provided(req, state) do
    Logger.info("content_types_provided, #{inspect(state.opts)}")
    {[@to_json], req, state}
  end

  def content_types_accepted(req, state) do
    Logger.info("content_types_accepted, #{inspect(state.opts)}")
    {[@from_json], req, state}
  end

  def allowed_methods(req, state) do
    Logger.info("allowed_methods, #{inspect(state.opts)}")
    {@methods, req, state}
  end

  def charsets_provided(req, state) do
    Logger.info("charsets_provided, #{inspect(state.opts)}")
    {[@utf8], req, state}
  end

  def delete_completed(req, state) do
    Logger.info("delete_completed, #{inspect(state.opts)}")
    {false, req, state}
  end

  def delete_resource(req, state) do
    Logger.info("delete_resource, #{inspect(state.opts)}")
    {false, req, state}
  end

  def forbidden(req, state) do
    Logger.info("forbidden, #{inspect(state.opts)}")
    {false, req, state}
  end

  def malformed_request(req0, state) do
    Logger.info("malformed_request, #{inspect(state.opts)}")

    req =
      if !state.schema do
        set_resp_body("\"Branch not exists\"", req0)
      else
        req0
      end

    {!state.schema, req, state}
  end

  def to_json(req, state) do
    Logger.info("to_json, #{inspect(state.output)}")
    json = "[" <> Enum.join(state.output, ",") <> "]"
    {json, req, state}
  end

  def from_json(req0, state) do
    Logger.info("from_json, #{inspect(state.input)}")
    req = set_resp_body(state.input, req0)
    {true, req, state}
  end

  def options(req0, state) do
    json = Jason.encode!(state.schema)
    req = reply(200, @headers, json, req0)
    {:ok, req, []}
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

defmodule Validator do
  @moduledoc false

  import Map, only: [take: 2, drop: 2, keys: 1, values: 1]
  import Enum, only: [count: 1, any?: 1, join: 2]
  import String, only: [capitalize: 1]
  import Regex, only: [compile!: 1]

  defp empty?(val) when is_map(val) or is_list(val), do: count(val) == 0
  defp empty?(val) when is_binary(val), do: val == ""
  defp empty?(val) when is_nil(val), do: true
  defp empty?(_), do: false

  defp len(val) when is_map(val) or is_list(val), do: count(val)
  defp len(val) when is_binary(val), do: String.length(val)
  defp len(val) when is_number(val), do: val
  defp len(_), do: 0

  defp wrong_type?(val, "integer") when is_integer(val), do: false
  defp wrong_type?(val, "number") when is_number(val), do: false
  defp wrong_type?(val, "string") when is_binary(val), do: false
  defp wrong_type?(val, "array") when is_list(val), do: false
  defp wrong_type?(val, "map") when is_map(val), do: false
  defp wrong_type?(_, _), do: true

  defp errors(model, schema) do
    for {key, spec} <- schema["leafs"], into: %{} do
      title = spec["title"] |> capitalize
      type = spec["type"]
      min = spec["min"]
      max = spec["max"]
      arr = spec["arr"]
      val = model[key]
      re = spec["re"]

      cond do
        wrong_type?(val, type) -> {title, "wrong format"}
        spec["required"] && empty?(val) -> {title, "required"}
        min && len(val) <= min -> {title, "too small (min: #{min})"}
        max && len(val) >= max -> {title, "too large (max: #{max})"}
        arr && !(val in arr) -> {title, "not in [#{join(arr, ", ")}]"}
        re && !Regex.match?(compile!(re), val) -> {title, "not matched (#{re})"}
        true -> {key, nil}
      end
    end
  end

  def process(model, schema) do
    errors = errors(model, schema)

    unless values(errors) |> any? do
      {:ok, model |> take(keys(errors))}
    else
      {:error, errors |> drop(keys(model))}
    end
  end
end
