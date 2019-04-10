defmodule Tree do
  @moduledoc false

  import :mnesia,
    only: [
      create_table: 2,
      add_table_index: 2
    ]

  # {id, branch, status} = id_br_st
  @struct [:id_br_st, :gid, :uid, :upd, :json]

  def init() do
    table(:tree, :set, @struct)
    table(:bag, :bag, @struct)
    table(:rel, :bag, @struct)
  end

  defp table(name, type, attrs) do
    create_table(
      name,
      [
        {:disc_copies, [node()]},
        {:attributes, attrs},
        {:type, type}
      ]
    )

    add_table_index(name, :uid)
    add_table_index(name, :gid)
    add_table_index(name, :upd)
  end
end

defmodule Tree.Store do
  @moduledoc false

  import :mnesia,
    only: [
      read: 1,
      write: 1,
      select: 2,
      transaction: 1,
      match_object: 1
    ]

  import Tree.Guards
  import Map, only: [put: 3]
  import UUID, only: [uuid4: 1]
  import Tuple, only: [append: 2]
  import Enum, only: [into: 3, join: 2]
  import String, only: [trim_trailing: 2]
  import Jason, only: [encode!: 2, decode!: 2]
  import List, only: [insert_at: 3, to_tuple: 1]

  @html [escape: :html_safe]
  @copy [strings: :copy]

  defp now do
    :os.system_time(:millisecond)
  end

  def post(branch, uid, gid, rec0) do
    id = uuid4(:hex)

    rec =
      rec0
      |> put("id", id)
      |> put("uid", uid)
      |> put("gid", gid)

    {:tree, {id, branch, :active}, gid, uid}
    |> post(rec)
  end

  defp post(tuple, rec) do
    now = now()
    json = encode!(rec, @html)

    {:atomic, result} =
      tuple
      |> append(now)
      |> append(json)
      |> write_fn()
      |> transaction()

    {result, rec["id"], now}
  end

  def get_all(db, branch, status, gid, uid) do
    t = {db, {:_, branch, status}, gid, uid, :_, :_}
    fn -> match_object(t) end
  end

  def get_one(db, branch, id, status \\ :active) do
    t = {id, branch, status}
    fn -> read({db, t}) end
  end

  def select(
        db,
        matchers,
        branch,
        status \\ :active,
        fields \\ [:"$5"]
      ) do
    id_br_st = {:"$1", branch, status}
    struct = {db, id_br_st, :"$2", :"$3", :"$4", :"$5"}
    match = {struct, matchers, fields}
    fn -> select(db, [match]) end
  end

  defp write_fn(tuple) do
    fn -> write(tuple) end
  end

  def in_match(field, list) do
    if length(list) != 0 do
      for val <- list do
        {:==, field, val}
      end
      |> insert_at(0, :or)
      |> to_tuple()
    else
      {:==, true, false}
    end
  end

  def list_json({:atomic, list}) do
    into(list, [], fn {_, _, _, _, _, json} -> json end)
  end

  def list_id({:atomic, list}) do
    into(list, [], fn {_, {id, _, _}, _, _, _, _} -> id end)
  end

  def map_id_json({:atomic, list}) do
    fun = fn {_, {id, _, _}, _, _, _, json} -> {id, json} end
    into(list, %{}, fun)
  end

  def to_json(map) when is_map(map) do
    fun = fn {k, v} -> "\"#{k}\":#{v}," end
    str = into(map, <<>>, fun) |> trim_trailing(",")
    "{" <> str <> "}"
  end

  def to_json(list) when is_empty_list(list), do: "[]"

  def to_json(list) when is_list(list),
    do: "[" <> join(list, ",") <> "]"

  def from_json(list) when is_one_in_list(list),
    do: hd(list) |> decode!(@copy)

  def get_from(db, branch, from \\ 0),
    do: select(db, [{:>, :"$4", from}], branch)

  def get_by_groups(db, branch, groups),
    do: select(db, [in_match(:"$2", groups)], branch)

  def get_by_branch(db, branch, status \\ :active),
    do: get_all(db, branch, status, :_, :_)

  def get_by_user(db, branch, uid, status \\ :active),
    do: get_all(db, branch, status, :_, uid)

  def get_by_group(db, branch, gid, status \\ :active),
    do: get_all(db, branch, status, gid, :_)
end

defmodule Tree.Do do
  @moduledoc false

  import Tree.Store

  import :mnesia,
    only: [transaction: 1]

  def to_json(req, state) do
    {"json", req, state}
  end

  def from_json(req, state) do
    {true, req, state}
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

  import Tree.Config, only: [schema: 1]
  import Logger, only: [info: 1]
  import Enum, only: [join: 2]

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
      state.type not in ["tree", "archive"] ->
        message = "\"Wrong type #{state.type}\""
        {true, set_resp_body(message, req), state}

      !state.schema ->
        message = "\"Wrong branch #{state.branch}\""
        {true, set_resp_body(message, req), state}

      true ->
        {false, req, state}
    end
  end

  def to_json(req, state) do
    info("to_json, #{inspect(state.list)}")
    json = "[" <> join(state.list, ",") <> "]"
    {json, req, state}
  end

  def from_json(req0, state) do
    info("from_json, #{inspect(state.input)}")
    req = set_resp_body(state.input, req0)
    {true, req, state}
  end
end
