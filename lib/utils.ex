defimpl Jason.Encoder, for: Tuple do
  def encode(tuple, opts \\ []) do
    Tuple.to_list(tuple)
    |> Jason.Encode.list(opts)
  end
end

defmodule Tree.Guards do
  defguard is_empty_list(list)
           when is_list(list) and length(list) == 0

  defguard is_one_in_list(list)
           when is_list(list) and length(list) == 1
end
