defmodule AssistantWeb.Shell.Layouts do
  use Phoenix.Component

  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="ru">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <meta name="theme-color" content="#f7f7f5" />
        <meta name="mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-title" content="clinker-app" />
        <meta name="csrf-token" content={Phoenix.Controller.get_csrf_token()} />
        <title>clinker-app</title>
        <link rel="manifest" href="/manifest.webmanifest" />
        <link rel="icon" href="/icons/icon-192.png" type="image/png" />
        <link rel="apple-touch-icon" href="/icons/apple-touch-icon.png" />
        <link rel="stylesheet" href="/assets/css/app.css" />
      </head>
      <body class="bg-paper font-sans text-ink">
        {@inner_content}
        <script src="/assets/phoenix/phoenix.min.js"></script>
        <script src="/assets/live/phoenix_live_view.min.js"></script>
        <script>
          const csrf = document.querySelector("meta[name='csrf-token']").getAttribute("content")
          const socket = new LiveView.LiveSocket("/live", Phoenix.Socket, {
            heartbeatIntervalMs: 30000,
            params: { _csrf_token: csrf }
          })
          socket.connect()
        </script>
      </body>
    </html>
    """
  end
end
