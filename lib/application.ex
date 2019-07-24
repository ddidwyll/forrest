defmodule Forrest.Application do
  @moduledoc false

  use Application
  alias :mnesia, as: Mnesia

  def start(_, _) do
    children = [
      Tree.Events,
      Tree.Auth
    ]

    opts = [
      strategy: :one_for_one,
      name: Forrest.Supervisor
    ]

    Mnesia.create_schema([node()])
    Mnesia.start()
    Tree.Config.init()
    Tree.Router.init()
    Tree.init()
    Supervisor.start_link(children, opts)
  end
end
