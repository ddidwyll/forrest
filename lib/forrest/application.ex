defmodule Forrest.Application do
  @moduledoc false

  use Application
  import Supervisor.Spec, only: [worker: 2]

  def start(_type, _args) do
    children = [
      worker(Events, [])
    ]

    opts = [
      strategy: :one_for_one,
      name: Forrest.Supervisor
    ]

    Router.start()
    Forrest.Auth.init()
    Supervisor.start_link(children, opts)
  end
end
