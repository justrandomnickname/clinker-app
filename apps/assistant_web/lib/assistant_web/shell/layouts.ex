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

            var full = window.innerHeight || 0
            var focused = false
            var frame = 0
            var shift = ""
            if (full) root.style.setProperty("--app-height", full + "px")

            function glue() {
              var layer = document.body
              if (!layer) return
              var vv = window.visualViewport
              var top = vv && vv.offsetTop > 0 ? Math.round(vv.offsetTop) : 0
              var next = top ? "translate3d(0," + top + "px,0)" : ""
              if (next !== shift) {
                layer.style.transform = next
                shift = next
              }
              if (window.scrollX || window.scrollY) window.scrollTo(0, 0)
            }

            function watch() {
              if (!focused) return
              glue()
              frame = requestAnimationFrame(watch)
            }

            function typing(target) {
              return !!(target && target.closest && target.closest("input, textarea, select, [contenteditable='true']"))
            }

            function strip() {
              var fields = document.querySelectorAll("[autofocus]")
              for (var i = 0; i < fields.length; i++) fields[i].removeAttribute("autofocus")
            }

            glue()
            if (window.visualViewport) {
              window.visualViewport.addEventListener("scroll", glue)
              window.visualViewport.addEventListener("resize", glue)
            }
            window.addEventListener("scroll", glue, { passive: true })
            window.addEventListener("orientationchange", function () {
              setTimeout(function () {
                if (focused) return
                full = window.innerHeight || 0
                if (full) root.style.setProperty("--app-height", full + "px")
                glue()
              }, 400)
            })
            document.addEventListener("touchstart", function (event) {
              if (!typing(event.target)) return
              if (!focused) {
                focused = true
                frame = requestAnimationFrame(watch)
              }
              glue()
              setTimeout(function () {
                if (typing(document.activeElement)) return
                focused = false
                cancelAnimationFrame(frame)
                glue()
              }, 700)
            }, true)
            document.addEventListener("focusin", function (event) {
              if (!typing(event.target)) return
              if (!focused) {
                focused = true
                frame = requestAnimationFrame(watch)
              }
              glue()
            }, true)
            document.addEventListener("focusout", function () {
              focused = false
              cancelAnimationFrame(frame)
              var settle = function () {
                glue()
                var vv = window.visualViewport
                if (vv && vv.offsetTop > 0) requestAnimationFrame(settle)
              }
              settle()
            }, true)
            var focus = HTMLElement.prototype.focus
            HTMLElement.prototype.focus = function (options) {
              var next = options ? options : {}
              next.preventScroll = true
              return focus.call(this, next)
            }
            strip()
            var autofocus = new MutationObserver(strip)
            autofocus.observe(document.documentElement, {
              childList: true,
              subtree: true,
              attributes: true,
              attributeFilter: ["autofocus"]
            })
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
            margin: 0;
            overflow: hidden;
            overscroll-behavior: none;
            padding-top: 0 !important;
          }

          html.ios-pwa .screen-visual {
            top: 0;
            bottom: auto;
            height: var(--app-height, 100%);
            transform: none;
            padding-top: 0 !important;
          }

          html.ios-pwa #log {
            padding-top: var(--figma-spacing-md) !important;
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
