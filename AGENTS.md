# assistant_web

Этот раздел только для `apps/assistant_web`. В `apps/assistant` так страницы не устраивать.

Человеческое объяснение тех же границ: `apps/assistant_web/lib/assistant_web/docs/page.md`. Ниже — как собирать код.

## Папки

Корень `lib/assistant_web`: `endpoint.ex`, `router.ex`, `application.ex`, `api_controller.ex`. Имена `Endpoint` и `Router` не менять.

- `shell` — layout и страницы ошибок
- `shared` — общее для страниц (`Shared.Page`) и компоненты, нужные двум и более фичам
- `features/<feature>/pages` — LiveView-страницы
- `features/<feature>/components/<name>/` — `name.ex` и `name.html.heex`
- `docs` — заметки для человека

Модуль повторяет путь: `AssistantWeb.Features.Chat.Pages.ChatLive`. Роут внутри `scope "/", AssistantWeb`: `live("/", Features.Chat.Pages.ChatLive)`.

Тест лежит рядом со страницей или компонентом. `test/` — только вход приложения и общее. Запускать из корня зонтика: `mix test apps/assistant_web/lib/assistant_web/features/...`. Из каталога приложения `mix test` не поднимает зависимости.

## Границы страницы

`*_live.ex` — ящик. Одна клауза на вход, без решений. Страница парсит payload (`phx-value` → тип) и возвращает `{:ok, socket}` или `{:noreply, socket}`.

`use AssistantWeb.Shared.Page` подставляет `handle_async` и `handle_info`. Они зовут соседние `__MODULE__.Request` (`loaded` / `failed`) и `__MODULE__.Screen` (`deliver`). На странице их не писать. Без `Request` и `Screen` этот `use` не подключать.

- `Event` — `handle_event`. Действие человека. Аргументы уже распарсены. Запись уходит в `Assistant` (`submit` и аналоги). Переход экрана — через `Screen`.
- `Request` — `mount` и `handle_async`. Имена задач `start_async`: что страница сама запросила. Функции: `boot`, `reload`, `loaded`, `failed`.
- `Screen` — состояние сокета и `handle_info`. `open`, `reset`, `put_*`, `deliver`, тексты ошибок. Общий переход (открыть чат) живёт здесь, даже если и клик, и ответ списка им пользуются.
- `Log` — чистые функции над данными этой страницы. Без сокета и без вызовов `Assistant`. Заводить только когда на странице есть такая структура.

`deliver` не переносить в `Request`. Если PubSub означает «перечитать», `Screen.deliver` вызывает `Request.reload`.

Компонент — function component (`use Phoenix.Component`, `embed_templates`). Не LiveComponent. Данные читает страница и передаёт атрибутами. Классы Tailwind писать целиком в шаблоне.

`start_async` — макрос. В модуле, который его вызывает: `require Phoenix.LiveView`. Подписка на PubSub только при `connected?(socket)`.

Поздний ответ не затирает экран, который уже ушёл дальше: чужой `chat_id` игнорировать; `put_phase` не пишет поверх фазы, которая уже `ok?`; повторный `select` того же чата — no-op.

Состояния журнала, списка и фазы держать в `Phoenix.LiveView.AsyncResult`.

## Figma

Макет читать через MCP `figma` (`https://mcp.figma.com/mcp`), конфиг в `.cursor/mcp.json`. Ссылка на кадр обязательна: из неё берутся `fileKey` и `node-id`. Имени кадра без ссылки на файл недостаточно.

Перед чтением файла вызвать `create_session` и передавать его `sessionId` дальше. Структуру слоя даёт `get_metadata`. Для вёрстки вызывать `get_design_context`, для цветов и шрифта этого кадра — `get_variable_defs`. Ответ переписывать в существующие шаблоны и `@theme`, не заменять страницу сгенерированным React.

Инструмента `get_figma_skill` нет. Навык читать через `FetchMcpResource`: server `project-0-personal-ai-figma`, uri `skill://figma/figma-design-to-code/SKILL.md`. В `get_design_context` передать `skillNames`: `resource:figma-design-to-code`. Порядок, ссылка на файл и токены — в `.cursor/skills/figma-skill/SKILL.md`.

Переменные кадра живут в `apps/assistant_web/assets/css/figma-tokens.css`. В шаблоне только их утилиты (`px-figma-xl`, `bg-brand`), не сырая длина и не hex.

## Новая страница

```
features/<feature>/pages/<page>_live.ex
features/<feature>/pages/<page>_live.html.heex
features/<feature>/pages/<page>_live_test.exs
features/<feature>/pages/<page>_live/event.ex
features/<feature>/pages/<page>_live/request.ex
features/<feature>/pages/<page>_live/screen.ex
```

Модуль без своего входа не создавать: нет событий — нет `Event`, нет своих запросов — нет `Request`.

```elixir
defmodule AssistantWeb.Features.Example.Pages.ExampleLive do
  use Phoenix.LiveView
  use AssistantWeb.Shared.Page

  alias AssistantWeb.Features.Example.Pages.ExampleLive.{Event, Request}

  def mount(_params, _session, socket), do: {:ok, Request.boot(socket)}

  def handle_event("name", %{"id" => id}, socket) do
    {:noreply, Event.name(socket, String.to_integer(id))}
  end
end
```

```elixir
defmodule AssistantWeb.Features.Example.Components.ExampleList do
  use Phoenix.Component

  embed_templates("example_list*")

  attr :items, :list, required: true
  def example_list(assigns)
end
```
