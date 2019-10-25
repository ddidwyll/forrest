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

defmodule Tree.Utils do
  import Tree.Guards

  def deep_merge(left, right) do
    Map.merge(left, right, &deep_resolve/3)
  end

  defp deep_resolve(_key, left = %{}, right = %{}) do
    deep_merge(left, right)
  end

  defp deep_resolve(_key, _left, right) do
    right
  end

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
