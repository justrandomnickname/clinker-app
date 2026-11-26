defmodule AssistantWeb.Shell.Layouts do
  use Phoenix.Component

  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="ru" class="fonts-pending">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover" />
        <meta name="theme-color" content="#f7f7f5" />
        <meta name="mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-title" content="clinker-app" />
        <meta name="csrf-token" content={Phoenix.Controller.get_csrf_token()} />
        <title>clinker-app</title>
        <link rel="manifest" href="/manifest.webmanifest" />
        <link rel="icon" href="/icons/icon-192.png" type="image/png" />
        <link rel="apple-touch-icon" href="/icons/apple-touch-icon.png" />
        <link rel="preload" href="/fonts/news-cycle-400-cyrillic.woff2" as="font" type="font/woff2" crossorigin="anonymous" />
        <link rel="preload" href="/fonts/news-cycle-400-latin.woff2" as="font" type="font/woff2" crossorigin="anonymous" />
        <link rel="preload" href="/fonts/news-cycle-700-latin.woff2" as="font" type="font/woff2" crossorigin="anonymous" />
        <link rel="stylesheet" href="/assets/css/app.css" />
        <style>
          html.fonts-pending {
            background: #f7f7f5;
          }

          html.fonts-pending body {
            visibility: hidden;
          }
        </style>
        <noscript>
          <style>
            html.fonts-pending body {
              visibility: visible;
            }
          </style>
        </noscript>
        <script>
          const root = document.documentElement
          const show = function () {
            root.classList.remove("fonts-pending")
          }
          if (!document.fonts || !document.fonts.load) {
            show()
          } else {
            const regular = document.fonts.load('400 16px "News Cycle"', "Аa")
            const bold = document.fonts.load('700 16px "News Cycle"', "A")
            setTimeout(show, 2000)
            Promise.all([regular, bold, document.fonts.ready]).then(show, show)
          }
        </script>
      </head>
      <body class="bg-paper font-sans text-ink">
        {@inner_content}
        <script src="/assets/phoenix/phoenix.min.js"></script>
        <script src="/assets/live/phoenix_live_view.min.js"></script>
        <script>
          const csrf = document.querySelector("meta[name='csrf-token']").getAttribute("content")
          window.addEventListener("click", function (event) {
            const el = event.target.closest("[data-confirm]")
            if (!el) return
            const message = el.getAttribute("data-confirm")
            if (!message) return
            if (!window.confirm(message)) {
              event.preventDefault()
              event.stopPropagation()
            }
          }, true)
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
