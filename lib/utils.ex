defimpl Jason.Encoder, for: Tuple do
  def encode(tuple, opts \\ []) do
    Tuple.to_list(tuple)
    |> Jason.Encode.list(opts)
  end
end

defmodule Tree.Guards do
  defguard is_empty_list(list)
           when is_list(list) and length(list) == 0

  defguard is_nonempty_list(list)
           when is_list(list) and length(list) > 0

  defguard is_one_in_list(list)
           when is_list(list) and length(list) == 1

  defguard is_empty_map(map)
           when is_map(map) and map_size(map) == 0
end

defmodule Tree.Functions do
end

defmodule Tree.Utils do
  import Tree.Guards
  import Map, only: [merge: 3]
  import Keyword, only: [has_key?: 2]

  alias Tree.Functions

  defp func_exist(name) do
    is_atom(name) &&
      has_key?(Functions.__info__(:functions), name)
  end

  def deep_compile(left, right, substitution)
      when is_map(left) and is_map(right) and is_map(substitution) do
    for {key, val} <- left, into: %{} do
      cond do
        is_map(val) && is_map(right[key]) ->
          {key, deep_compile(val, right[key], substitution)}

        func_exist(right[key]) ->
          {key, apply(Functions, right[key], [left])}

        val == true && is_atom(right[key]) ->
          {key, substitution[right[key]]}

        true ->
          {key, val}
      end
    end
  end

  def deep_compile(left, _, _) when is_map(left) do
    left
  end

  def deep_merge(left, right), do: merge(left || %{}, right || %{}, &deep_resolve/3)
  defp deep_resolve(_key, left = %{}, right = %{}), do: deep_merge(left, right)
  defp deep_resolve(_, _, right), do: right

  def deep_get(lvls, map) when is_one_in_list(lvls) and is_map(map) do
    [key] = lvls
    if key == "", do: map, else: map[key]
  end

  def deep_get(lvls0, map) when is_nonempty_list(lvls0) and is_map(map) do
    [key, lvls] = lvls0
    deep_get(lvls, map[key])
  end

  def deep_get(lvls, map) when is_empty_list(lvls) and is_map(map), do: map

  def deep_get(key, map) when is_map(map), do: map[key]

  def deep_get(_, _), do: nil

  def deep_set(lvls0, value, map, tmp0 \\ nil) when is_nonempty_list(lvls0) do
    [key | lvls] = lvls0

    cond do
      !tmp0 ->
        tmp = %{key => value}
        deep_set(lvls, value, map, tmp)

      true ->
        tmp = deep_merge(%{}, %{key => tmp0})
        deep_set(lvls, value, map, tmp)
    end
  end

  def deep_set(lvls, _, map0, tmp) when is_empty_list(lvls) do
    map = map0 || %{}

    if !tmp do
      map
    else
      deep_merge(map, tmp)
    end
  end
end

defmodule Tree.Compiler do
  def compile(string, name) do
    with {:ok, func} <- Code.string_to_quoted(string) do
      quote do
        defmodule Tree.Functions do
          def unquote(name)(struct) do
            unquote(func).(struct || %{})
          end
        end
      end
      |> Code.compile_quoted()

      :ok
    else
      _ -> :error
    end
  end
end
