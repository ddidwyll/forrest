defmodule Router do
  @moduledoc false

  def start do
    :cowboy.start_clear(
      :http,
      [{:port, 8080}],
      %{env: %{dispatch: routes()}}
    )
  end

  def routes do
    :cowboy_router.compile([
      {:_,
       [
         {"/", :cowboy_static, {:file, "./priv/index.html"}},
         {"/events/:user/[:last_id]", Events.Route, []}
       ]}
    ])
  end
end
