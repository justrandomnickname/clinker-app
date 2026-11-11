defmodule AssistantWeb.Features.Context.Pages.ContextLiveTest do
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint AssistantWeb.Endpoint

  test "a russian word opens its chat address" do
    {:ok, view, _html} = live(build_conn(), "/")

    assert {:error, {:live_redirect, %{to: "/chat/bytovoe"}}} =
             view |> form("#context", %{text: "бытовое"}) |> render_submit()
  end

  test "an empty word stays on the entrance" do
    {:ok, view, _html} = live(build_conn(), "/")
    html = view |> form("#context", %{text: "  "}) |> render_submit()
    assert html =~ "Введите контекст"
  end

  test "no_context is refused on the entrance" do
    {:ok, view, _html} = live(build_conn(), "/")
    html = view |> form("#context", %{text: "no_context"}) |> render_submit()
    assert html =~ "Такой контекст нельзя"
  end
end
