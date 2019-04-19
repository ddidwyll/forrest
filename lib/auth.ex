defmodule Tree.Auth do
  @moduledoc false

  use GenServer
  use Joken.Config
  import Tree.Config, only: [env: 1]
  import Joken, only: [current_time: 0]
  import Joken.Signer, only: [create: 2]

  import GenServer,
    only: [call: 2, start_link: 3]

  def start_link(_) do
    start_link(
      __MODULE__,
      nil,
      name: :auth
    )
  end

  @impl true
  def init(_) do
    # :mnesia.create_table(
    #   :events,
    #   [
    #     {:disc_copies, [node()]},
    #     {:type, :ordered_set},
    #     {:attributes, @event}
    #   ]
    # )

    state = %{
      signer: create("HS256", env("secret"))
    }

    {:ok, state}
  end

  @impl true
  def token_config do
    host = env("host")

    add_claim(
      %{},
      "host",
      fn -> host end,
      &(&1 == host)
    )
    |> add_claim(
      "exp",
      fn ->
        current_time() + 30 * 24 * 3600
      end,
      &(current_time() < &1)
    )
  end

  @impl true
  def handle_call({:token, claims}, _, state) do
    t = generate_and_sign!(claims, state.signer)
    {:reply, t, state}
  end

  @impl true
  def handle_call({:claims, token}, _, state) do
    claims =
      case verify_and_validate(token, state.signer) do
        {:ok, claims} -> claims
        {:error, _} -> %{}
      end

    {:reply, claims, state}
  end

  def token(claims \\ %{}), do: call(:auth, {:token, claims})
  def claims(token), do: call(:auth, {:claims, token})
end
