defmodule AssistantWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :assistant_web

  @session_options [
    store: :cookie,
    key: "_assistant_key",
    signing_salt: "assistant-sign",
    same_site: "Lax"
  ]

  socket("/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: false
  )

  plug(Plug.Static, at: "/", from: :assistant_web, only: ~w(assets fonts icons manifest.webmanifest))
  plug(Plug.Static, at: "/assets/phoenix", from: {:phoenix, "priv/static"})
  plug(Plug.Static, at: "/assets/live", from: {:phoenix_live_view, "priv/static"})

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)
  plug(Plug.Session, @session_options)
  plug(AssistantWeb.Router)
end
