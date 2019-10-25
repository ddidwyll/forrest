defmodule Tree.Main do
  @moduledoc false

  import Tree.Store
  import Tree.Guards
  import Tree.Validator
  import Tree.Config, only: [env: 1]
  import Tree.Events, only: [event: 4]
  import String, only: [capitalize: 1]

  import :cowboy_req,
    only: [read_body: 1, set_resp_body: 2]

  import Jason,
    only: [decode: 2, encode!: 2]

  @copy [strings: :copy]
  @html [escape: :html_safe]

  defp get_body({req, state}) do
    with {:ok, json, _} <- read_body(req),
         {:ok, body} <- decode(json, @copy) do
      {:ok, req, %{state | in: body}}
    else
      {:error, e} ->
        message = "Invalid json #{e.position || ""}"
        {:error, req, %{state | out: message}}
    end
  end

  defp validate({result, req, state}) do
    with :ok <- result,
         %{in: r, schema: s} <- state,
         {:ok, rec} <- process(r, s) do
      {:ok, req, %{state | in: rec}}
    else
      {:error, e} -> {:error, req, %{state | out: e}}
      _ -> {:error, req, state}
    end
  end

  def message({result, req0, state}) do
    req =
      unless state.out,
        do: req0,
        else:
          state.out
          |> encode!(@html)
          |> set_resp_body(req0)

    {result, req, state}
  end

  defp title(state) do
    state.branch
  end

  defp create({result, req, state}) do
    if result == :ok do
      {:ok, id, time} =
        post(
          state.branch,
          state.uid,
          state.gid,
          state.in
        )

      message = state.branch <> " posted successful"
      {:ok, req, %{state | to: time, from: id, out: message}}
    else
      {result, req, state}
    end
  end

  defp update({result, req, state}) do
    if result == :ok do
      {:ok, _, time} =
        put(
          state.branch,
          state.from,
          state.uid,
          state.gid,
          "active",
          state.in
        )

      message = title(state) <> " updated successful"
      {true, req, %{state | to: time, out: message}}
    else
      {result, req, state}
    end
  end

  defp event({result, req, state}, action) do
    if result == true || result == :ok do
      event(
        state.branch,
        state.from,
        action,
        state.to
      )
    end

    {result, req, state}
  end

  defp result({result, req, state}) do
    cond do
      result == :ok && !state.to ->
        {true, req, state}

      result == :ok && state.to ->
        url = "//rest.#{env("host")}/#{state.branch}/#{state.to}"
        {{true, url}, req, state}

      true ->
        {false, req, state}
    end
  end

  def exist(req, state) do
    with false <- is_nil(state.from),
         list <-
           get_one(
             state.type,
             state.branch,
             state.from
           ),
         false <- is_empty_list(list),
         {_, _, gid, uid, upd, json} <- hd(list) do
      {
        true,
        req,
        %{state | gid: gid, uid: uid, upd: upd, out: json}
      }
    else
      _ -> {false, req, state}
    end
  end

  def status(state) do
    statuses =
      if state.from,
        do:
          get_all(
            state.type,
            state.branch,
            :_,
            :_,
            :_,
            state.from
          )
          |> list_status,
        else: []

    cond do
      is_empty_list(statuses) ->
        state

      statuses == [:deleted] || :deleted in [statuses] ->
        %{state | out: title(state) <> " deleted"}

      statuses == [:blocked] || :blocked in [statuses] ->
        %{state | out: title(state) <> " blocked"}

      statuses == [:archived] || :archived in [statuses] ->
        to = {true, "//arch.#{env("host")}/#{state.branch}/#{state.from}"}
        %{state | out: title(state) <> " moved to archive", to: to}
    end
  end

  def post(req, state) do
    {req, state}
    |> get_body()
    |> validate()
    |> create()
    |> message()
    |> event("post")
    |> result()
  end

  def put(req, state) do
    {req, state}
    |> get_body()
    |> validate()
    |> update()
    |> message()
    |> event("put")
  end

  def delete({req, state}) do
    unless state.to do
      case delete(state.branch, state.from) do
        {:ok, time} ->
          {true, req, %{state | to: time}}
          |> event("delete")

        err ->
          IO.inspect(err)
          {false, req, state}
      end
    end
  end
end
