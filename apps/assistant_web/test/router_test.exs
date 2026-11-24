defmodule AssistantWeb.RouterTest do
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Plug.Conn

  @endpoint AssistantWeb.Endpoint

  test "the chat can be installed" do
    html = html_response(get(build_conn(), "/"), 200)

    assert html =~ "<title>clinker-app</title>"
    assert html =~ ~s(name="apple-mobile-web-app-title" content="clinker-app")
    assert html =~ ~s(rel="manifest" href="/manifest.webmanifest")
    assert html =~ ~s(rel="apple-touch-icon" href="/icons/apple-touch-icon.png")
    assert html =~ ~s(name="theme-color" content="#f7f7f5")
    assert html =~ ~s(name="mobile-web-app-capable" content="yes")

    conn = get(build_conn(), "/manifest.webmanifest")
    assert get_resp_header(conn, "content-type") == ["application/manifest+json"]

    manifest = json_response(conn, 200)
    assert manifest["name"] == "clinker-app"
    assert manifest["short_name"] == "clinker-app"
    assert manifest["id"] == "/"
    assert manifest["start_url"] == "/"
    assert manifest["scope"] == "/"
    assert manifest["display"] == "standalone"
    assert manifest["theme_color"] == "#f7f7f5"
    assert manifest["background_color"] == "#f7f7f5"

    for icon <- manifest["icons"] do
      file = get(build_conn(), icon["src"])
      assert file.status == 200
      assert get_resp_header(file, "content-type") == ["image/png"]
    end

    apple = get(build_conn(), "/icons/apple-touch-icon.png")
    assert apple.status == 200
    assert get_resp_header(apple, "content-type") == ["image/png"]
  end

  test "health is alive and the old paths are gone" do
    conn = get(build_conn(), "/api/health")
    assert json_response(conn, 200) == %{"ok" => true}

    assert get(build_conn(), "/health").status == 404
    assert post_json("/chat", %{prompt: "hi"}).status == 404
  end

  test "chat requires a prompt string" do
    assert json_response(post_json("/api/chat", %{}), 400)["error"] =~ "prompt"
    assert json_response(post_json("/api/chat", %{prompt: 1}), 400)["error"] =~ "prompt"
  end

  test "an empty mcp token closes the entrance" do
    conn = mcp_post(%{"jsonrpc" => "2.0", "id" => 1, "method" => "tools/list"}, nil)
    assert conn.status == 401
    refute conn.resp_body =~ "list_cards"
    refute conn.resp_body =~ "slug"
  end

  test "a wrong token is refused without card text" do
    previous = Application.get_env(:cards, :repo)
    Application.put_env(:cards, :repo, %{previous | mcp_token: "test-token"})
    on_exit(fn -> Application.put_env(:cards, :repo, previous) end)

    conn =
      mcp_post(
        %{
          "jsonrpc" => "2.0",
          "id" => 1,
          "method" => "tools/call",
          "params" => %{"name" => "get_card", "arguments" => %{"slug" => "genserver"}}
        },
        "Bearer wrong-token"
      )

    assert conn.status == 401
    refute conn.resp_body =~ "genserver"
    refute conn.resp_body =~ "title"
  end

  defp mcp_post(body, auth) do
    conn =
      build_conn()
      |> put_req_header("content-type", "application/json")
      |> put_req_header("accept", "application/json, text/event-stream")

    conn =
      if is_binary(auth) do
        put_req_header(conn, "authorization", auth)
      else
        conn
      end

    post(conn, "/mcp", Jason.encode!(body))
  end

  defp post_json(path, body) do
    build_conn()
    |> put_req_header("content-type", "application/json")
    |> put_req_header("accept", "application/json")
    |> post(path, Jason.encode!(body))
  end
end
