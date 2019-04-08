defmodule Router do
  @moduledoc false

  import Config, only: [env: 1]
  import :cowboy, only: [start_clear: 3]
  import :cowboy_router, only: [compile: 1]

  @routes [
    {"/", :cowboy_static, {:file, "./client/public/index.html"}},
    {"/assets/[...]", :cowboy_static, {:dir, "./client/public/"}},
    {"/upload/[...]", :cowboy_static, {:dir, "./upload/"}},
    {"/events/:user/[:last_id]", Events.Route, nil},
    {"/:type/:branch/[:params]", Tree.Route, nil}
  ]

  def start do
    start_clear(
      :http,
      [{:port, env("port")}],
      %{
        env: %{dispatch: routes()},
        idle_timeout: env("events_timeout")
      }
    )
  end

  def routes do
    compile([{env("host"), @routes}])
  end
end
