defmodule Forrest.Application do
  @moduledoc false

  use Application
  alias :mnesia, as: Mnesia

  def start(_, _) do
    children = [
      Tree.Config,
      Tree.Events,
      Tree.Auth
    ]

    opts = [
      strategy: :one_for_one,
      name: Forrest.Supervisor
    ]

    Mnesia.create_schema([node()])
    Mnesia.start()
    {:ok, pid} = Supervisor.start_link(children, opts)
    Tree.init()
    Tree.Router.init()
    {:ok, pid}
  end
end
