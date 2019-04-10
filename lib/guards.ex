defmodule Tree.Guards do
  defguard is_empty_list(list)
           when is_list(list) and length(list) == 0

  defguard is_one_in_list(list)
           when is_list(list) and length(list) == 1
end
