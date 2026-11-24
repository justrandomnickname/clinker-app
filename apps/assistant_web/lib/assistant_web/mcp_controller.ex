defmodule AssistantWeb.McpController do
  use Phoenix.Controller, formats: [:json]

  @protocol "2025-06-18"
  @supported ~w(2025-03-26 2025-06-18)

  def call(conn, _params) do
    case authorize(conn) do
      :ok -> dispatch(conn, conn.body_params)
      :closed -> unauthorized(conn)
      :forbidden -> unauthorized(conn)
    end
  end

  def method_not_allowed(conn, _params) do
    case authorize(conn) do
      :ok ->
        conn
        |> put_resp_header("allow", "POST")
        |> send_resp(405, "")

      _ ->
        unauthorized(conn)
    end
  end

  defp dispatch(conn, %{"jsonrpc" => "2.0", "method" => method} = message) when is_binary(method) do
    if Map.has_key?(message, "id") do
      request(conn, message["id"], method, message["params"] || %{})
    else
      send_resp(conn, 202, "")
    end
  end

  defp dispatch(conn, _body) do
    json_error(conn, nil, -32600, "invalid request")
  end

  defp request(conn, id, "initialize", params) do
    version = params["protocolVersion"]
    version = if version in @supported, do: version, else: @protocol

    json_result(conn, id, %{
      "protocolVersion" => version,
      "capabilities" => %{"tools" => %{}},
      "serverInfo" => %{"name" => "memory-cards", "version" => "1.0.0"},
      "instructions" => Cards.instructions()
    })
  end

  defp request(conn, id, "tools/list", _params) do
    json_result(conn, id, %{"tools" => Cards.tools()})
  end

  defp request(conn, id, "tools/call", params) do
    name = params["name"]
    args = params["arguments"] || %{}
    packed = Cards.pack(Cards.dispatch(name, args))

    json_result(conn, id, %{
      "content" => [%{"type" => "text", "text" => Jason.encode!(packed)}],
      "isError" => packed["ok"] != true
    })
  end

  defp request(conn, id, "ping", _params) do
    json_result(conn, id, %{})
  end

  defp request(conn, id, _method, _params) do
    json_error(conn, id, -32601, "method not found")
  end

  defp authorize(conn) do
    expected = Cards.mcp_token()
    given = bearer(conn)

    cond do
      expected == "" ->
        :closed

      given == "" ->
        :forbidden

      byte_size(given) != byte_size(expected) ->
        :forbidden

      Plug.Crypto.secure_compare(given, expected) ->
        :ok

      true ->
        :forbidden
    end
  end

  defp bearer(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] -> String.trim(token)
      ["bearer " <> token] -> String.trim(token)
      _ -> ""
    end
  end

  defp unauthorized(conn) do
    conn
    |> put_status(401)
    |> json(%{error: "unauthorized"})
  end

  defp json_result(conn, id, result) do
    json(conn, %{"jsonrpc" => "2.0", "id" => id, "result" => result})
  end

  defp json_error(conn, id, code, message) do
    conn
    |> put_status(400)
    |> json(%{"jsonrpc" => "2.0", "id" => id, "error" => %{"code" => code, "message" => message}})
  end
end
