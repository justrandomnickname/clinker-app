defmodule AssistantWeb.Features.Chat.Pages.ChatLiveTest do
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint AssistantWeb.Endpoint

  setup do
    Req.Test.set_req_test_to_shared()

    Req.Test.stub(AssistantInference.Gemini, fn conn ->
      model = AssistantInference.Gemini.model()

      body =
        Jason.encode!(%{
          "models" => [
            %{
              "name" => "models/#{model}",
              "inputTokenLimit" => 1_000,
              "supportedGenerationMethods" => ["generateContent"]
            }
          ]
        })

      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(200, body)
    end)

    Assistant.Reply.reset_all()
    Assistant.Repo.delete_all(Assistant.Journal.Message)
    Assistant.Repo.delete_all(Assistant.Journal.Chat)
    :ok
  end

  test "the reply arrives on the open chat" do
    Req.Test.stub(AssistantInference.Gemini, fn conn ->
      case conn.method do
        "GET" ->
          model = AssistantInference.Gemini.model()

          body =
            Jason.encode!(%{
              "models" => [
                %{
                  "name" => "models/#{model}",
                  "supportedGenerationMethods" => ["generateContent"]
                }
              ]
            })

          conn
          |> Plug.Conn.put_resp_content_type("application/json")
          |> Plug.Conn.send_resp(200, body)

        "POST" ->
          payload = %{
            "candidates" => [%{"content" => %{"parts" => [%{"text" => "готов"}]}}],
            "usageMetadata" => %{
              "promptTokenCount" => 2,
              "candidatesTokenCount" => 1,
              "thoughtsTokenCount" => 0
            }
          }

          conn
          |> Plug.Conn.put_resp_content_type("text/event-stream")
          |> Plug.Conn.send_resp(200, "data: #{Jason.encode!(payload)}\n\n")
      end
    end)

    {:ok, view, _html} = live(build_conn(), "/chat")
    render_async(view, 1_000)
    view |> form("#composer", %{text: "привет"}) |> render_submit()

    html = await_text(view, "готов")
    assert html =~ "привет"
    assert html =~ "<p>готов</p>"
    refute html =~ "<p>привет</p>"
  end

  test "clicking a chat opens its messages" do
    older = chat("Старый")
    _newer = chat("Новый")

    Assistant.Repo.insert!(%Assistant.Journal.Message{
      chat_id: older.id,
      seq: 1,
      role: "user",
      content: "из старого",
      status: "complete"
    })

    {:ok, view, _html} = live(build_conn(), "/chat")
    html = render_async(view, 1_000)
    assert html =~ "Старый"
    assert html =~ "Новый"
    refute html =~ "из старого"

    view |> element("#chat-#{older.id}") |> render_click()
    html = render_async(view, 1_000)
    assert html =~ "из старого"
    assert html =~ "Новый"
  end

  test "the new chat button opens an empty chat" do
    chat("Старый")

    {:ok, view, _html} = live(build_conn(), "/chat")
    render_async(view, 1_000)

    view |> element("#new-chat") |> render_click()
    html = render_async(view, 1_000)
    [new, older] = Assistant.list_chats()

    assert html =~ "Начать новый чат"
    assert html =~ "Старый"
    assert new.title == "Новый чат"
    assert new.context == "misc"
    assert older.title == "Старый"
    assert view |> element("#chat-#{new.id}") |> render() =~ "bg-paper"
    refute view |> element("#chat-#{older.id}") |> render() =~ "bg-paper"
  end

  test "a context shows only its chats" do
    chat("Дом", "bytovoe")
    chat("Код", "code")

    {:ok, view, _html} = live(build_conn(), "/chat/bytovoe")
    html = render_async(view, 1_000)
    assert html =~ "Дом"
    refute html =~ "Код"
    assert view |> element("#context-label") |> render() =~ "bytovoe"

    assert {:error, {:live_redirect, %{to: "/"}}} =
             view |> element("#context-label") |> render_click()
  end

  test "the full list shows every context" do
    chat("Дом", "bytovoe")
    chat("Код", "code")

    {:ok, view, _html} = live(build_conn(), "/chat")
    html = render_async(view, 1_000)
    assert html =~ "Дом"
    assert html =~ "Код"
    assert view |> element("#context-label") |> render() =~ "все"
  end

  test "a new chat keeps the open context" do
    {:ok, view, _html} = live(build_conn(), "/chat/bytovoe")
    render_async(view, 1_000)
    view |> element("#new-chat") |> render_click()
    render_async(view, 1_000)

    chats = Assistant.list_chats("bytovoe")
    assert length(chats) == 2
    assert Enum.all?(chats, &(&1.context == "bytovoe"))
  end

  test "no_context and a cyrillic address rewrite to a canonical path" do
    assert {:error, {:live_redirect, %{to: "/chat"}}} = live(build_conn(), "/chat/no_context")

    assert {:error, {:live_redirect, %{to: "/chat/bytovoe"}}} =
             live(build_conn(), "/chat/бытовое")
  end

  test "a broken address returns to the entrance" do
    assert {:error, {:live_redirect, %{to: "/"}}} = live(build_conn(), "/chat/---")
  end

  defp chat(title, context \\ "misc") do
    {:ok, chat} = Assistant.create_chat(context)

    chat
    |> Ecto.Changeset.change(title: title, updated_at: DateTime.utc_now(:second))
    |> Assistant.Repo.update!()
  end

  defp await_text(view, text, left \\ 20) do
    html = render(view)

    cond do
      html =~ text ->
        html

      left == 0 ->
        flunk(html)

      true ->
        Process.sleep(50)
        await_text(view, text, left - 1)
    end
  end
end
