defmodule Tree.Store do
  @moduledoc false

  import :mnesia,
    only: [
      read: 1,
      write: 1,
      select: 2,
      delete: 1,
      transaction: 1,
      match_object: 1
    ]

  import Tree.Guards
  import Map, only: [put: 3]
  import UUID, only: [uuid4: 1]
  import Tuple, only: [append: 2]
  import Enum, only: [into: 3, join: 2]
  import Jason, only: [encode!: 2, decode!: 2]
  import List, only: [insert_at: 3, to_tuple: 1]
  import String, only: [trim_trailing: 2, to_atom: 1]

  @html [escape: :html_safe]
  @copy [strings: :copy]

  defp now, do: :os.system_time(:millisecond)

  def delete(branch, id, status \\ :active) do
    {:atomic, result} =
      fn -> delete({:tree, {id, branch, status}}) end
      |> transaction

    {result, now() |> to_string()}
  end

  def put(branch, id, status0, rec0) do
    IO.inspect(rec0)
    rec = %{rec0 | "upd" => now() |> to_string()}

    status =
      if status0 in ["deleted", "archived"] do
        to_atom(status0)
      else
        delete(branch, id)
        :undefined
      end

    {
      :tree,
      {id, branch, status},
      rec["gid"],
      rec["uid"]
    }
    |> post(rec, rec["upd"])
  end

  def post(branch, uid, gid, rec0, status \\ :active) do
    id = uuid4(:hex)
    now = now() |> to_string

    rec =
      rec0
      |> put("id", id)
      |> put("uid", uid)
      |> put("gid", gid)
      |> put("upd", now)

    {:tree, {id, branch, status}, gid, uid}
    |> post(rec, now)
  end

  defp post(tuple, rec, time \\ nil) do
    now = (time || now()) |> to_string
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
    fn -> read({db, {id, branch, status}}) end
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
    unless is_empty_list(list) do
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

  def list_json({:aborted, {:no_exists, nil}}), do: []

  def list_id({:atomic, list}) do
    into(list, [], fn {_, {id, _, _}, _, _, _, _} -> id end)
  end

  def list_id({:aborted, {:no_exists, nil}}), do: []

  def list_status({:atomic, list}) do
    into(list, [], fn {_, {_, _, status}, _, _, _, _} -> status end)
  end

  def list_status({:aborted, {:no_exists, nil}}), do: []

  def list({:atomic, list}) when is_list(list), do: list
  def list({:aborted, {:no_exists, nil}}), do: []

  def map_id_json({:atomic, list}) do
    fun = fn {_, {id, _, _}, _, _, _, json} -> {id, json} end
    into(list, %{}, fun)
  end

  def to_json(map) when is_map(map) do
    fun = fn {k, v} -> "\"#{k}\":#{v}," end
    str = into(map, <<>>, fun) |> trim_trailing(",")
    "{" <> str <> "}"
  end

  def to_json([]), do: "[]"

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
