defmodule AssistantWeb.Features.Cards.Pages.CardsLiveTest do
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint AssistantWeb.Endpoint

  test "the list shows the store is unavailable" do
    {:ok, view, _html} = live(build_conn(), "/cards")
    html = render_async(view)
    assert html =~ "Хранилище недоступно"
  end
end
