defmodule Tree do
  @moduledoc false

  import :mnesia,
    only: [
      create_table: 2,
      add_table_index: 2
    ]

  @struct [:id, :to, :from, :upd, :json]

  def init do
    table(:tree, :set)
    table(:meta, :bag)
    table(:refs, :bag)
  end

  defp table(name, type) do
    create_table(
      name,
      [
        {:disc_copies, [node()]},
        {:attributes, @struct},
        {:type, type}
      ]
    )

    add_table_index(name, :upd)
    add_table_index(name, :to)
    add_table_index(name, :from)
  end
end
