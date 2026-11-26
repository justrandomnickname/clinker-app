defmodule AssistantWeb.Shell.Layouts do
  use Phoenix.Component

  def root(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="ru">
      <head>
        <meta charset="utf-8" />
        <meta
          name="viewport"
          content="width=device-width, initial-scale=1, viewport-fit=cover"
        />
        <script>
          (function () {
            var ua = navigator.userAgent || ""
            var ios = /iPad|iPhone|iPod/.test(ua) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1)
            var standalone = navigator.standalone === true || window.matchMedia("(display-mode: standalone)").matches
            if (!ios || !standalone) return

            var root = document.documentElement
            root.classList.add("ios-pwa")
            var meta = document.querySelector('meta[name="viewport"]')
            if (meta && meta.content.indexOf("interactive-widget") === -1) {
              meta.setAttribute("content", meta.content + ", interactive-widget=overlays-content")
            }

            var full = 0
            var locked = false
            var generation = 0
            var lastHeight = ""
            var lastTop = ""
            var watching = false

            function layoutHeight() {
              var vv = window.visualViewport
              var inner = window.innerHeight || 0
              var visual = vv ? vv.height + (vv.offsetTop || 0) : inner
              return Math.round(Math.max(inner, visual))
            }

            function sync() {
              var vv = window.visualViewport
              var measured = layoutHeight()
              if (!locked && measured) full = measured
              if (!full) full = measured || window.innerHeight || 0
              var top = locked && vv && vv.offsetTop > 0 ? Math.round(vv.offsetTop) : 0
              var height = full + "px"
              var shift = top + "px"
              if (height !== lastHeight) {
                root.style.setProperty("--app-height", height)
                lastHeight = height
              }
              if (shift !== lastTop) {
                root.style.setProperty("--vv-top", shift)
                lastTop = shift
              }
              if (window.scrollY) window.scrollTo(0, 0)
              if (document.body && document.body.scrollTop) document.body.scrollTop = 0
              var shell = document.querySelector(".screen-visual")
              if (shell && shell.scrollTop) shell.scrollTop = 0
            }

            function watch() {
              if (!watching) return
              sync()
              requestAnimationFrame(watch)
            }

            function typing(target) {
              return !!(target && target.closest && target.closest("input, textarea, select, [contenteditable='true']"))
            }

            sync()
            if (window.visualViewport) {
              window.visualViewport.addEventListener("resize", sync)
              window.visualViewport.addEventListener("scroll", sync)
            }
            window.addEventListener("scroll", sync, { passive: true })
            window.addEventListener("orientationchange", function () {
              locked = false
              full = 0
              setTimeout(sync, 400)
            })
            window.addEventListener("pageshow", function () {
              locked = false
              full = 0
              sync()
            })
            document.addEventListener("touchstart", function (event) {
              if (!typing(event.target)) return
              generation += 1
              var token = generation
              var measured = layoutHeight()
              if (measured && measured > full) full = measured
              locked = true
              setTimeout(function () {
                if (token !== generation || watching) return
                locked = false
                sync()
              }, 700)
            }, true)
            document.addEventListener("focusin", function (event) {
              if (!typing(event.target)) return
              generation += 1
              var measured = layoutHeight()
              if (measured && measured > full) full = measured
              locked = true
              if (watching) return
              watching = true
              requestAnimationFrame(watch)
            }, true)
            document.addEventListener("focusout", function () {
              var token = generation
              watching = false
              setTimeout(function () {
                if (token !== generation) return
                locked = false
                sync()
              }, 500)
            }, true)
          })()
        </script>
        <style>
          html.ios-pwa,
          html.ios-pwa body {
            position: fixed;
            top: 0;
            right: 0;
            left: 0;
            bottom: auto;
            width: 100%;
            height: var(--app-height, 100%);
            overflow: hidden;
            overscroll-behavior: none;
          }

          html.ios-pwa .screen-visual {
            top: 0;
            bottom: auto;
            height: var(--app-height, 100%);
            transform: translate3d(0, var(--vv-top, 0px), 0);
          }
        </style>
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
