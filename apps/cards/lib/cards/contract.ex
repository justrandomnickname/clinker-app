defmodule Cards.Contract do
  @instructions """
  title — имя предмета одной строкой. Не абзац и не slug.
  tags — токены тем [a-z0-9-]. Не фразы и не повтор заголовка. До 32, список может быть пустым.
  body — markdown: о чём карточка, какое решение, ссылки [[slug]]. Строк --- в теле нет. Тело непустое и короче 32 КБ.
  slug — латинское имя файла [a-z0-9-], до 64 символов. После создания не меняется.
  source — clinker или короткое имя проекта. Обязателен при создании, при обновлении остаётся.
  Поле вне этих правил — отказ. Удаления нет. За ход открывай не больше трёх карточек.
  """

  def instructions, do: String.trim(@instructions)

  def tools do
    [
      tool(
        "list_cards",
        "Список карточек. Несколько тегов — пересечение, пустой список — все заголовки.",
        %{
          "tags" => %{
            "type" => "array",
            "items" => %{"type" => "string"}
          }
        },
        []
      ),
      tool(
        "get_card",
        "Одна карточка по slug: тело, исходящие [[slug]] и входящие ссылки.",
        %{"slug" => %{"type" => "string"}},
        ["slug"]
      ),
      tool(
        "create_card",
        "Создать карточку полями. Файл и шапку пишет дверь. Существующий slug — отказ.",
        %{
          "slug" => %{"type" => "string"},
          "title" => %{"type" => "string"},
          "tags" => %{"type" => "array", "items" => %{"type" => "string"}},
          "source" => %{"type" => "string"},
          "body" => %{"type" => "string"}
        },
        ["slug", "title", "tags", "source", "body"]
      ),
      tool(
        "update_card",
        "Обновить карточку целиком. source не передаётся и остаётся. Отсутствующий slug — отказ.",
        %{
          "slug" => %{"type" => "string"},
          "title" => %{"type" => "string"},
          "tags" => %{"type" => "array", "items" => %{"type" => "string"}},
          "body" => %{"type" => "string"}
        },
        ["slug", "title", "tags", "body"]
      )
    ]
  end

  def mcp_token do
    case config()[:mcp_token] do
      token when is_binary(token) -> String.trim(token)
      _ -> ""
    end
  end

  def explain({:invalid, text}) when is_binary(text), do: text
  def explain(:unavailable), do: "Хранилище недоступно"
  def explain(:exists), do: "Создать существующий slug — отказ."
  def explain(:missing), do: "Обновить отсутствующий slug — отказ."
  def explain(:conflict), do: "Карточка изменилась. Прочитай её заново."
  def explain(:unknown_tool), do: "Нет такого инструмента."
  def explain(other), do: inspect(other)

  def pack({:ok, result}), do: %{"ok" => true, "result" => result}
  def pack({:error, reason}), do: %{"ok" => false, "error" => explain(reason)}

  def invalid, do: {:error, {:invalid, instructions()}}

  defp config, do: Application.get_env(:cards, :repo, %{})

  defp tool(name, description, properties, required) do
    schema = %{
      "type" => "object",
      "properties" => properties,
      "additionalProperties" => false
    }

    schema = if required == [], do: schema, else: Map.put(schema, "required", required)

    %{
      "name" => name,
      "description" => description,
      "inputSchema" => schema
    }
  end
end
