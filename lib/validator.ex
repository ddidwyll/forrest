defmodule Tree.Validator do
  @moduledoc false

  import Tree.Utils, only: [deep_merge: 2]

  import Enum,
    only: [
      with_index: 1,
      filter: 2,
      count: 1,
      join: 2,
      any?: 1
    ]

  import Map,
    only: [
      new: 1,
      keys: 1,
      take: 2,
      drop: 2,
      values: 1,
      has_key?: 2
    ]

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
  defp wrong_type?(val, "bool") when is_boolean(val), do: false
  defp wrong_type?(val, "array") when is_list(val), do: false
  defp wrong_type?(val, "map") when is_map(val), do: false
  defp wrong_type?(_, "any"), do: false
  defp wrong_type?(_, _), do: true

  defp collapse(val) when is_map(val), do: val |> values |> collapse
  defp collapse(val) when is_list(val), do: val |> filter(& &1) |> join(", ")
  defp collapse(val) when is_binary(val), do: val
  defp collapse(val), do: to_string(val)

  defp struct?(val, struct) when is_list(val) do
    for {v, i} <- with_index(val) do
      key = to_string(i)
      errors(%{key => v}, %{key => struct}) |> collapse
    end
    |> collapse
  end

  defp struct?(val, struct) when is_map(val) do
    errors(val, struct) |> collapse
  end

  defp errors(model, schema) when is_map(model) and is_map(schema) do
    for {key, spec} <- schema, is_map(spec), into: %{} do
      title = (spec["title"] || key) <> ":"
      required = spec["required"]
      struct = spec["struct"]
      re = spec["regexp"]
      type = spec["type"]
      min = spec["min"]
      max = spec["max"]
      possible = spec["possible"]
      impossible = spec["impossible"]
      val = model[key]

      cond do
        !has_key?(model, key) && !required ->
          {key, nil}

        required && empty?(val) ->
          {key, "#{title} required"}

        wrong_type?(val, type) ->
          {key, "#{title} must be #{type}"}

        min && len(val) < min ->
          {key, "#{title} too small (min: #{min})"}

        max && len(val) > max ->
          {key, "#{title} too large (max: #{max})"}

        struct && struct?(val, struct) != "" ->
          {key, "#{title} #{struct?(val, struct)}"}

        possible && val not in possible ->
          {key, "#{title} not in [#{join(possible, ", ")}]"}

        impossible && val in impossible ->
          {key, "#{title} in [#{join(impossible, ", ")}]"}

        re && !Regex.match?(re, val) ->
          {key, "#{title} not match (#{inspect(re)})"}

        true ->
          {key, nil}
      end
    end
  end

  def process(model, schema0) when is_map(model) and is_map(schema0) do
    schema =
      drop(schema0, [
        "api_title",
        "default",
        "regexp",
        "api_type",
        "type",
        "api_type"
      ])

    errors =
      errors(model, schema)
      |> filter(fn {_, v} -> !!v end)
      |> new

    if map_size(errors) == 0 do
      result = model |> take(keys(schema))
      default = schema0["default"] || %{}
      {:ok, deep_merge(default, result)}
    else
      {:error, errors}
    end
  end

  def process(_, _),
    do: {:error, %{"JSON:" => "wrong format"}}
end
