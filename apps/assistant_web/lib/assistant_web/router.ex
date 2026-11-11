defmodule AssistantWeb.Router do
  use Phoenix.Router

  import Phoenix.LiveView.Router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_live_flash)
    plug(:put_root_layout, html: {AssistantWeb.Shell.Layouts, :root})
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  scope "/", AssistantWeb do
    pipe_through(:browser)

    live_session :chat do
      live("/", Features.Context.Pages.ContextLive)
      live("/chat", Features.Chat.Pages.ChatLive)
      live("/chat/:context", Features.Chat.Pages.ChatLive)
    end
  end

  scope "/api", AssistantWeb do
    pipe_through(:api)

    get("/health", ApiController, :health)
    post("/chat", ApiController, :chat)
  end
end
