defmodule Router do
  @moduledoc false

  def start do
    :cowboy.start_clear(
      :http,
      [{:port, 8080}],
      %{
        env: %{dispatch: routes()},
        idle_timeout: 5 * 60_000
      }
    )
  end

  def routes do
    :cowboy_router.compile([
      {:_,
       [
         {"/", :cowboy_static, {:file, "./priv/index.html"}},
         {"/events/:user/[:last_id]", Events.Route, []},
         {"/tree/:branch/[:id]", Tree.Route, []}
       ]}
    ])
  end
end
