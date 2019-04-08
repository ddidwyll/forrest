defmodule Validator do
  @moduledoc false

  import Enum, only: [count: 1, any?: 1, join: 2]
  import String, only: [capitalize: 1]

  import Map,
    only: [
      take: 2,
      drop: 2,
      keys: 1,
      values: 1,
      has_key?: 2,
      merge: 2
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
  defp wrong_type?(_, _), do: true

  defp errors(model, schema) do
    for {key, spec} <- schema["leafs"], into: %{} do
      title = (spec["title"] <> ":") |> capitalize
      re = schema["regexps"][key]
      required = spec["required"]
      type = spec["type"]
      min = spec["min"]
      max = spec["max"]
      arr = spec["arr"]
      val = model[key]

      cond do
        !has_key?(model, key) && !required -> {key, nil}
        required && empty?(val) -> {title, "required"}
        wrong_type?(val, type) -> {title, "must be #{type}"}
        min && len(val) <= min -> {title, "too small (min: #{min})"}
        max && len(val) >= max -> {title, "too large (max: #{max})"}
        arr && val not in arr -> {title, "not in [#{join(arr, ", ")}]"}
        re && !Regex.match?(re, val) -> {title, "not match (#{inspect(re)})"}
        true -> {key, nil}
      end
    end
  end

  def process(model, schema) when is_map(model) do
    errors = errors(model, schema)

    unless values(errors) |> any? do
      result = model |> take(keys(errors))
      default = schema["defaults"] || %{}
      {:ok, merge(default, result)}
    else
      {:error, errors |> drop(keys(model))}
    end
  end

  def process(_, _),
    do: {:error, %{"JSON:" => "wrong format"}}
end
