defmodule Tree do
  @moduledoc false

  import :mnesia,
    only: [
      create_table: 2,
      add_table_index: 2
    ]

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

  def get_all(db, branch, status, gid, uid, id \\ :_) do
    t = {db, {id, branch, status}, gid, uid, :_, :_}

    fn -> match_object(t) end
    |> transaction()
  end

  def get_one(db, branch, id, status \\ :active) do
    t = {id, branch, status}

    fn -> read({db, t}) end
    |> transaction()
    |> list()
  end

  def select(
        db,
        matchers,
        branch,
        fields \\ [:"$5"],
        status \\ :active
      ) do
    id_br_st =
      if branch,
        do: {:"$1", branch, status},
        else: :"$1"

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

  def list_status({:atomic, list}) do
    into(list, [], fn {_, {_, _, status}, _, _, _, _} -> status end)
  end

  def list({:atomic, list}) when is_list(list), do: list

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
    do: select(db, [{:>, :"$4", from}], branch, [[:"$4", :"$1"]])

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

  #
  #
  #
  #
  #

  import Tree.Store
  import Tree.Guards
  import Tree.Validator
  import String, only: [capitalize: 1]

  # import :mnesia,
  #   only: [transaction: 1]

  import :cowboy_req,
    only: [read_body: 1, set_resp_body: 2]

  import Jason,
    only: [decode: 2, encode!: 2]

  @copy [strings: :copy]
  @html [escape: :html_safe]

  defp get_body({req, state}) do
    with {:ok, json, _} <- read_body(req),
         {:ok, body} <- decode(json, @copy) do
      {:ok, req, %{state | in: body}}
    else
      {:error, e} ->
        message = "Invalid json #{e.position || ""}"
        {:error, req, %{state | out: message}}
    end
  end

  defp validate({result, req, state}) do
    with :ok <- result,
         %{in: r, schema: s} <- state,
         {:ok, rec} <- process(r, s) do
      {:ok, req, %{state | in: rec}}
    else
      {:error, e} -> {:error, req, %{state | out: e}}
      _ -> {:error, req, state}
    end
  end

  defp message({result, req0, state}) do
    req =
      unless state.out,
        do: req0,
        else:
          state.out
          |> encode!(@html)
          |> set_resp_body(req0)

    {result, req, state}
  end

  defp title(state) do
    capitalize(state.schema["title"]) <> " "
  end

  defp write({result, req, state}) do
    if result == :ok do
      {:ok, id, time} =
        post(
          state.branch,
          state.uid,
          state.gid,
          state.in
        )

      message = title(state) <> "was posted"
      {:ok, req, %{state | from: time, to: id, out: message}}
    else
      {result, req, state}
    end
  end

  defp result({result, req, state}) do
    cond do
      result == :ok && !state.to ->
        {true, req, state}

      result == :ok && state.to ->
        uri = "/tree/#{state.branch}/#{state.to}"
        {{true, uri}, req, state}

      true ->
        {false, req, state}
    end
  end

  def exist(req, state) do
    with false <- is_nil(state.from),
         list <-
           get_one(
             state.schema["type"],
             state.branch,
             state.from
           ),
         true <- is_one_in_list(list),
         [{_, _, gid, uid, upd, json}] <- list do
      {
        true,
        req,
        %{state | gid: gid, uid: uid, upd: upd, out: json}
      }
    else
      0 -> {false, req, state}
      _ -> {false, req, state}
    end
  end

  def status(state) do
    statuses =
      get_all(
        state.schema["type"],
        state.branch,
        :_,
        :_,
        :_,
        state.from
      )
      |> list_status

    cond do
      is_empty_list(statuses) ->
        %{state | out: title(state) <> "not found"}

      statuses == [:deleted] || :deleted in [statuses] ->
        %{state | out: title(state) <> "deleted"}

      statuses == [:blocked] || :blocked in [statuses] ->
        %{state | out: title(state) <> "blocked"}

      statuses == [:archived] || :archived in [statuses] ->
        to = "/archive/#{state.branch}/#{state.from}"
        %{state | out: title(state) <> "archived", to: to}
    end
  end

  def post(req, state) do
    {req, state}
    |> get_body()
    |> validate()
    |> write()
    |> message()
    |> result()
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

  import :erlang,
    only: [posixtime_to_universaltime: 1]

  import Tree.Config, only: [schema: 1]
  import Logger, only: [info: 1]
  import Tree.Do

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
  def init(req0, _) do
    state = %{
      schema: schema(req0.bindings.branch),
      branch: req0.bindings.branch,
      from: req0.bindings[:from],
      type: req0.bindings.type,
      to: req0.bindings[:to],
      method: req0.method,
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
  def resource_exists(req, state) do
    info("resource_exists")
    exist(req, state)
  end

  @impl true
  def previously_existed(req, state) do
    info("previously_existed")
    {false, req, state}
  end

  @impl true
  def delete_resource(req, state) do
    info("delete_resource")
    {false, req, state}
  end

  @impl true
  def is_authorized(req, state) do
    info("is_authorized")
    {true, req, state}
  end

  @impl true
  def last_modified(req, state) do
    info("last_modified")

    last_mod =
      state.upd
      |> div(1000)
      |> posixtime_to_universaltime()

    {last_mod, req, state}
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
    {state.out, req, state}
  end

  def from_json(req, state) do
    case state.method do
      "POST" -> post(req, state)
    end
  end
end
