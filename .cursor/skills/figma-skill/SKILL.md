---
name: figma-skill
description: >-
  Loads Figma MCP skills when get_figma_skill is missing, pulls variable
  defs into figma-tokens.css, and reads a frame into Phoenix HEEx. Use before
  get_design_context, use_figma, generate_diagram, create_new_file, shader or
  generative-plugin tools, and whenever the user shares a figma.com link or
  asks to implement a frame or update tokens.
---

# Figma

Инструмента `get_figma_skill` нет. Навыки Figma — ресурсы MCP. Прочитать ресурс, выполнить его, и только потом вызывать инструмент файла.

## Загрузка

`FetchMcpResource` в namespace `cursor`:

- `server`: `project-0-personal-ai-figma`
- `uri`: адрес навыка из таблицы ниже

Если сервер не находится, повторить с `server`: `figma`. Список всех навыков: `skill://index.json`.

## Перед инструментом

| Инструмент | Сначала прочитать |
| --- | --- |
| `get_design_context` | `skill://figma/figma-design-to-code/SKILL.md` |
| `use_figma` | `skill://figma/figma-use/SKILL.md` |
| `generate_diagram` | `skill://figma/figma-generate-diagram/SKILL.md` |
| `create_new_file` | `skill://figma/figma-create-new-file/SKILL.md` |
| `create_shader`, `update_shader` | `skill://figma/figma-shaders/SKILL.md` |
| `create_generative_plugin`, `update_generative_plugin` | `skill://figma/figma-generative-plugins/SKILL.md` |

В `get_design_context` передать `skillNames`: `resource:figma-design-to-code`.

## Кадр в этот проект

1. Из ссылки взять `fileKey` и `node-id`. `1-2` записать как `1:2`.
2. `create_session` на namespace `project-0-personal-ai-figma`. Его `sessionId` передавать дальше.
3. Прочитать навык design-to-code, затем `get_design_context` с `clientLanguages`: `elixir,html,css` и `clientFrameworks`: `phoenix,liveview`. Цвета и шрифт кадра — `get_variable_defs`.
4. Ответ на React переписать в существующие HEEx-шаблоны. Страницу сгенерированным React не заменять. Имена слоёв и вариантов — это договор, что менять в коде.

## Токены

Файл: [https://www.figma.com/design/hQzZQXnO6nl3jucPRwE8X8/Untitled?node-id=1-2](https://www.figma.com/design/hQzZQXnO6nl3jucPRwE8X8/Untitled?node-id=1-2). `fileKey` — `hQzZQXnO6nl3jucPRwE8X8`.

Значения переменных писать только в `apps/assistant_web/assets/css/figma-tokens.css`. В шаблоне сырой длины и цвета нет: ни `px-[22px]`, ни `#fff06a`.

После `create_session` вызвать `get_variable_defs` на узле из ссылки. Пустой ответ значит, что переменные висят на вложенном компоненте: взять его id из `get_metadata` и запросить ещё раз.

Как имя из Figma ложится в CSS:

| Переменная Figma | Ключ в `@theme` | Класс |
| --- | --- | --- |
| `brand` | `--color-brand` | `bg-brand`, `text-brand` |
| `bttn-radius-md` | `--radius-bttn-md` | `rounded-bttn-md` |
| `spacing-xl` | `--figma-spacing-xl` | `px-figma-xl`, `gap-figma-xl` |

Число без единицы — пиксели. Отступ Figma не класть в `--spacing-sm` или `--spacing-xl`: эти имена в Tailwind занимают ещё и `max-w-sm` / `max-w-xl`. Поэтому шаг токена идёт после `figma-`, а утилиты `p-figma-*`, `px-figma-*`, `py-figma-*`, `m-figma-*`, `gap-figma-*` читают `--figma-spacing-*`.
