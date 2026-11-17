defmodule Assistant.Cards do
  use GenServer

  require Logger

  @body_max 32 * 1024
  @token ~r/^[a-z0-9-]{1,64}$/
  @instructions """
  title — имя предмета одной строкой. Не абзац и не slug.
  tags — токены тем [a-z0-9-]. Не фразы и не повтор заголовка. До 32, список может быть пустым.
  body — markdown: о чём карточка, какое решение, ссылки [[slug]]. Строк --- в теле нет. Тело непустое и короче 32 КБ.
  slug — латинское имя файла [a-z0-9-], до 64 символов. После создания не меняется.
  source — clinker или короткое имя проекта. Обязателен при создании, при обновлении остаётся.
  Поле вне этих правил — отказ. Удаления нет. За ход открывай не больше трёх карточек.
  """

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def instructions, do: String.trim(@instructions)

  def tools do
    [
      tool("list_cards", "Список карточек. Несколько тегов — пересечение, пустой список — все заголовки.", %{
        "tags" => %{
          "type" => "array",
          "items" => %{"type" => "string"}
        }
      }, []),
      tool("get_card", "Одна карточка по slug: тело, исходящие [[slug]] и входящие ссылки.", %{
        "slug" => %{"type" => "string"}
      }, ["slug"]),
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

  def list(tags) when is_list(tags) do
    GenServer.call(__MODULE__, {:list, clean_tags(tags)}, 60_000)
  end

  def get(slug) when is_binary(slug) do
    if slug =~ @token do
      GenServer.call(__MODULE__, {:get, slug}, 60_000)
    else
      {:error, :missing}
    end
  end

  def create(slug, title, tags, source, body) do
    with {:ok, fields} <- cast_create(slug, title, tags, source, body) do
      GenServer.call(__MODULE__, {:create, fields}, 120_000)
    end
  end

  def update(slug, title, tags, body) do
    with {:ok, fields} <- cast_update(slug, title, tags, body) do
      GenServer.call(__MODULE__, {:update, fields}, 120_000)
    end
  end

  def dispatch("list_cards", args), do: list_dispatch(stringify(args))
  def dispatch("get_card", args), do: get_dispatch(stringify(args))
  def dispatch("create_card", args), do: create_dispatch(stringify(args))
  def dispatch("update_card", args), do: update_dispatch(stringify(args))
  def dispatch(name, nil) when is_binary(name), do: dispatch(name, %{})
  def dispatch(_, _), do: invalid()

  @impl true
  def init(_opts) do
    root = config()[:root] || Path.join(System.tmp_dir!(), "clinker-cards")

    {:ok,
     %{status: :booting, root: root, tip: nil, cards: %{}, by_tag: %{}}, {:continue, :boot}}
  end

  @impl true
  def handle_continue(:boot, state) do
    state =
      try do
        boot(state)
      rescue
        error ->
          Logger.warning("cards boot failed: #{Exception.message(error)}")
          unavailable(state)
      end

    {:noreply, state}
  end

  @impl true
  def handle_call({:list, tags}, _from, %{status: :ready} = state) do
    {:reply, {:ok, headers(state, tags)}, state}
  end

  def handle_call({:list, _tags}, _from, state) do
    {:reply, {:error, :unavailable}, state}
  end

  def handle_call({:get, slug}, _from, %{status: :ready} = state) do
    {:reply, read_card(state, slug), state}
  end

  def handle_call({:get, _slug}, _from, state) do
    {:reply, {:error, :unavailable}, state}
  end

  def handle_call({:create, fields}, _from, state) do
    write(state, :create, fields)
  end

  def handle_call({:update, fields}, _from, state) do
    write(state, :update, fields)
  end

  defp boot(state) do
    case credentials() do
      {:ok, url, token} ->
        case fetch(url, token) do
          {:ok, tip, files} -> install(state, tip, files)
          :error -> unavailable(state)
        end

      :error ->
        unavailable(state)
    end
  end

  defp unavailable(state), do: %{state | status: :unavailable}

  defp write(%{status: :ready} = state, op, fields) do
    case prepare_write(state, op, fields) do
      {:ok, state, content} ->
        case push(state, op, fields.slug, content, false) do
          {:ok, state} -> {:reply, {:ok, %{slug: fields.slug}}, state}
          {:error, reason, state} -> {:reply, {:error, reason}, state}
        end

      {:error, reason, state} ->
        {:reply, {:error, reason}, state}
    end
  end

  defp write(state, _op, _fields), do: {:reply, {:error, :unavailable}, state}

  defp prepare_write(state, op, fields) do
    before = read_bytes(state, fields.slug)

    case sync(state) do
      {:ok, state} ->
        after_bytes = read_bytes(state, fields.slug)

        cond do
          op == :create and Map.has_key?(state.cards, fields.slug) ->
            {:error, :exists, state}

          op == :update and not Map.has_key?(state.cards, fields.slug) ->
            {:error, :missing, state}

          before != after_bytes ->
            {:error, :conflict, state}

          true ->
            case encode(op, fields, state) do
              {:ok, content} -> {:ok, state, content}
              {:error, reason} -> {:error, reason, state}
            end
        end

      :error ->
        {:error, :unavailable, state}
    end
  end

  defp sync(%{tip: tip} = state) do
    with {:ok, url, token} <- credentials(),
         {:ok, owner, repo} <- repo(url),
         {:ok, remote} <- remote_tip(owner, repo, token) do
      if remote == tip do
        {:ok, state}
      else
        fetch_into(state, url, token)
      end
    else
      _ -> :error
    end
  end

  defp fetch_into(state, url, token) do
    case fetch(url, token) do
      {:ok, tip, files} -> {:ok, install(state, tip, files)}
      :error -> :error
    end
  end

  defp encode(:create, fields, _state) do
    {:ok, document(fields.title, fields.tags, fields.source, fields.body)}
  end

  defp encode(:update, fields, state) do
    case state.cards[fields.slug] do
      %{source: source} when is_binary(source) ->
        if source =~ @token do
          {:ok, document(fields.title, fields.tags, source, fields.body)}
        else
          invalid()
        end

      _ ->
        invalid()
    end
  end

  defp push(state, op, slug, content, retried?) do
    with {:ok, url, token} <- credentials(),
         {:ok, owner, repo} <- repo(url) do
      sha = if op == :update, do: state.cards[slug].blob, else: nil

      case commit(owner, repo, token, slug, message(op, slug), content, sha) do
        {:ok, tip, blob} ->
          {:ok, remember(state, slug, content, tip, blob)}

        {:error, :conflict} when not retried? ->
          retry_push(state, op, slug, content)

        {:error, :conflict} ->
          {:error, :conflict, refetch(state)}

        {:error, _} ->
          {:error, :unavailable, state}
      end
    else
      _ -> {:error, :unavailable, state}
    end
  end

  defp retry_push(state, op, slug, content) do
    before = read_bytes(state, slug)

    case credentials() do
      {:ok, url, token} ->
        case fetch_into(state, url, token) do
          {:ok, state} ->
            cond do
              op == :create and Map.has_key?(state.cards, slug) ->
                {:error, :exists, state}

              op == :update and not Map.has_key?(state.cards, slug) ->
                {:error, :missing, state}

              read_bytes(state, slug) != before ->
                {:error, :conflict, state}

              true ->
                push(state, op, slug, content, true)
            end

          :error ->
            {:error, :unavailable, state}
        end

      :error ->
        {:error, :unavailable, state}
    end
  end

  defp refetch(state) do
    case credentials() do
      {:ok, url, token} ->
        case fetch_into(state, url, token) do
          {:ok, state} -> state
          :error -> state
        end

      :error ->
        state
    end
  end

  defp remember(state, slug, content, tip, blob) do
    File.mkdir_p!(state.root)
    File.write!(path(state, slug), content)
    card = index_one(slug, content)
    card = if is_binary(blob), do: %{card | blob: blob}, else: card
    old = state.cards[slug]
    cards = Map.put(state.cards, slug, card)

    by_tag = retag(state.by_tag, slug, (old && old.tags) || [], card.tags)
    %{state | cards: cards, by_tag: by_tag, tip: tip || state.tip, status: :ready}
  end

  defp install(state, tip, files) do
    File.mkdir_p!(state.root)
    keep = MapSet.new(Enum.map(files, fn {slug, _} -> slug <> ".md" end))

    case File.ls(state.root) do
      {:ok, names} ->
        Enum.each(names, fn name ->
          if String.ends_with?(name, ".md") and name not in keep do
            File.rm(Path.join(state.root, name))
          end
        end)

      _ ->
        :ok
    end

    Enum.each(files, fn {slug, content} ->
      File.write!(path(state, slug), content)
    end)

    {cards, by_tag} =
      Enum.reduce(files, {%{}, %{}}, fn {slug, content}, {cards, by_tag} ->
        card = index_one(slug, content)
        {Map.put(cards, slug, card), add_tags(by_tag, slug, card.tags)}
      end)

    %{state | status: :ready, tip: tip, cards: cards, by_tag: by_tag}
  end

  defp headers(state, tags) do
    state
    |> slugs(tags)
    |> Enum.map(fn slug ->
      card = Map.fetch!(state.cards, slug)

      %{
        slug: slug,
        title: card.title,
        tags: card.tags,
        source: card.source,
        broken: card.broken
      }
    end)
  end

  defp slugs(state, []), do: state.cards |> Map.keys() |> Enum.sort()

  defp slugs(state, tags) do
    tags
    |> Enum.map(fn tag -> Map.get(state.by_tag, tag, MapSet.new()) end)
    |> Enum.reduce(&MapSet.intersection/2)
    |> MapSet.to_list()
    |> Enum.sort()
  end

  defp read_card(state, slug) do
    case Map.get(state.cards, slug) do
      nil ->
        {:error, :missing}

      card ->
        content = read_bytes(state, slug) || ""
        {:ok, present(state, slug, card, content)}
    end
  end

  defp present(state, slug, card, content) do
    {body, broken} =
      case parse(content) do
        {:ok, fields} -> {fields.body, card.broken}
        :error -> {content, true}
      end

    %{
      slug: slug,
      title: card.title,
      tags: card.tags,
      source: card.source,
      body: body,
      outgoing: card.outgoing,
      incoming: incoming(state, slug),
      broken: broken
    }
  end

  defp incoming(state, slug) do
    state.cards
    |> Enum.filter(fn {other, card} -> other != slug and slug in card.outgoing end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.sort()
  end

  defp index_one(slug, content) do
    blob = blob_sha(content)

    parsed =
      if String.valid?(content) do
        parse(content)
      else
        :error
      end

    case parsed do
      {:ok, fields} ->
        if valid_stored?(slug, fields) do
          %{
            title: fields.title,
            tags: fields.tags,
            source: fields.source,
            outgoing: links(fields.body),
            broken: false,
            blob: blob
          }
        else
          broken_card(fields, blob)
        end

      :error ->
        blank_card(blob)
    end
  end

  defp broken_card(fields, blob) do
    %{
      title: fields.title,
      tags: fields.tags,
      source: fields.source,
      outgoing: [],
      broken: true,
      blob: blob
    }
  end

  defp blank_card(blob) do
    %{title: nil, tags: [], source: nil, outgoing: [], broken: true, blob: blob}
  end

  defp valid_stored?(slug, fields) do
    match?(:ok, validate(slug, fields.title, fields.tags, fields.source, fields.body))
  end

  defp add_tags(by_tag, _slug, []), do: by_tag

  defp add_tags(by_tag, slug, tags) do
    Enum.reduce(tags, by_tag, fn tag, acc ->
      Map.update(acc, tag, MapSet.new([slug]), &MapSet.put(&1, slug))
    end)
  end

  defp retag(by_tag, slug, old_tags, new_tags) do
    by_tag =
      Enum.reduce(old_tags, by_tag, fn tag, acc ->
        case Map.get(acc, tag) do
          nil ->
            acc

          set ->
            set = MapSet.delete(set, slug)
            if MapSet.size(set) == 0, do: Map.delete(acc, tag), else: Map.put(acc, tag, set)
        end
      end)

    add_tags(by_tag, slug, new_tags)
  end

  defp list_dispatch(args) do
    cond do
      args == %{} ->
        list([])

      match?(%{"tags" => tags} when is_list(tags), args) and map_size(args) == 1 ->
        if Enum.all?(args["tags"], &is_binary/1) and clean_tags(args["tags"]) == args["tags"] do
          list(args["tags"])
        else
          invalid()
        end

      true ->
        invalid()
    end
  end

  defp get_dispatch(args) do
    case args do
      %{"slug" => slug} when map_size(args) == 1 ->
        if is_binary(slug) and slug =~ @token, do: get(slug), else: invalid()

      _ ->
        invalid()
    end
  end

  defp create_dispatch(args) when is_map(args) do
    fields = ~w(slug title tags source body)

    if Enum.sort(Map.keys(args)) == Enum.sort(fields) do
      create(args["slug"], args["title"], args["tags"], args["source"], args["body"])
    else
      invalid()
    end
  end

  defp create_dispatch(_), do: invalid()

  defp update_dispatch(args) when is_map(args) do
    fields = ~w(slug title tags body)

    if Enum.sort(Map.keys(args)) == Enum.sort(fields) do
      update(args["slug"], args["title"], args["tags"], args["body"])
    else
      invalid()
    end
  end

  defp update_dispatch(_), do: invalid()

  defp cast_create(slug, title, tags, source, body) do
    title = if is_binary(title), do: String.trim(title), else: title
    body = normalize_body(body)

    case validate(slug, title, tags, source, body) do
      :ok -> {:ok, %{slug: slug, title: title, tags: tags, source: source, body: body}}
      {:error, _} = error -> error
    end
  end

  defp cast_update(slug, title, tags, body) do
    title = if is_binary(title), do: String.trim(title), else: title
    body = normalize_body(body)

    with :ok <- validate_slug(slug),
         :ok <- validate_title(title, slug),
         :ok <- validate_tags(tags, title),
         :ok <- validate_body(body) do
      {:ok, %{slug: slug, title: title, tags: tags, body: body}}
    else
      :error -> invalid()
    end
  end

  defp validate(slug, title, tags, source, body) do
    with :ok <- validate_slug(slug),
         :ok <- validate_title(title, slug),
         :ok <- validate_tags(tags, title),
         :ok <- validate_source(source),
         :ok <- validate_body(body) do
      :ok
    else
      :error -> invalid()
    end
  end

  defp validate_slug(slug) when is_binary(slug) do
    if slug =~ @token, do: :ok, else: :error
  end

  defp validate_slug(_), do: :error

  defp validate_title(title, slug) when is_binary(title) do
    cond do
      title == "" -> :error
      String.contains?(title, "\n") or String.contains?(title, "\r") -> :error
      String.length(title) > 120 -> :error
      String.downcase(title) == slug -> :error
      true -> :ok
    end
  end

  defp validate_title(_, _), do: :error

  defp validate_tags(tags, title) when is_list(tags) and length(tags) <= 32 do
    down = if is_binary(title), do: String.downcase(title), else: ""
    if Enum.all?(tags, &valid_tag?(&1, down)), do: :ok, else: :error
  end

  defp validate_tags(_, _), do: :error

  defp valid_tag?(tag, title) when is_binary(tag) do
    tag =~ @token and tag != title
  end

  defp valid_tag?(_, _), do: false

  defp validate_source(source) when is_binary(source) do
    if source =~ @token, do: :ok, else: :error
  end

  defp validate_source(_), do: :error

  defp validate_body(body) when is_binary(body) do
    cond do
      String.trim(body) == "" -> :error
      byte_size(body) >= @body_max -> :error
      fence?(body) -> :error
      true -> :ok
    end
  end

  defp validate_body(_), do: :error

  defp fence?(body) do
    body |> String.split("\n") |> Enum.any?(fn line -> String.trim(line) == "---" end)
  end

  defp normalize_body(body) when is_binary(body) do
    body |> String.replace("\r\n", "\n") |> String.replace("\r", "\n")
  end

  defp normalize_body(body), do: body

  defp invalid, do: {:error, {:invalid, instructions()}}

  defp clean_tags(tags) do
    tags
    |> Enum.filter(&is_binary/1)
    |> Enum.map(&String.downcase/1)
    |> Enum.filter(&(&1 =~ @token))
    |> Enum.uniq()
  end

  defp stringify(nil), do: %{}

  defp stringify(args) when is_map(args) do
    Map.new(args, fn {key, value} -> {to_string(key), value} end)
  end

  defp stringify(_), do: :bad

  def parse(binary) when is_binary(binary) do
    text = binary |> String.replace("\r\n", "\n")

    case String.split(text, "\n", parts: 2) do
      ["---", rest] ->
        case split_header(rest) do
          {:ok, lines, body} -> decode_header(lines, body)
          :error -> :error
        end

      _ ->
        :error
    end
  end

  def parse(_), do: :error

  defp split_header(rest) do
    {header, tail} = Enum.split_while(String.split(rest, "\n"), &(&1 != "---"))

    case tail do
      ["---" | body] -> {:ok, header, Enum.join(body, "\n")}
      _ -> :error
    end
  end

  defp decode_header(lines, body) do
    Enum.reduce_while(lines, {:ok, %{}}, fn line, {:ok, acc} ->
      case header_line(line) do
        :skip ->
          {:cont, {:ok, acc}}

        {:ok, key, value} ->
          if Map.has_key?(acc, key) do
            {:halt, :error}
          else
            {:cont, {:ok, Map.put(acc, key, value)}}
          end

        :error ->
          {:halt, :error}
      end
    end)
    |> case do
      {:ok, %{"title" => title, "tags" => tags, "source" => source}} ->
        {:ok, %{title: title, tags: tags, source: source, body: body}}

      _ ->
        :error
    end
  end

  defp header_line(""), do: :skip

  defp header_line(line) do
    case String.split(line, ":", parts: 2) do
      [key, raw] when key in ["title", "source"] ->
        case scalar(String.trim(raw)) do
          {:ok, value} -> {:ok, key, value}
          :error -> :error
        end

      ["tags", raw] ->
        case tag_list(String.trim(raw)) do
          {:ok, tags} -> {:ok, "tags", tags}
          :error -> :error
        end

      _ ->
        :error
    end
  end

  defp scalar("\"" <> rest) do
    if String.ends_with?(rest, "\"") do
      unescape(binary_part(rest, 0, byte_size(rest) - 1), "")
    else
      :error
    end
  end

  defp scalar(text) do
    if text == "" or String.contains?(text, ":"), do: :error, else: {:ok, text}
  end

  defp unescape("\\" <> <<char, rest::binary>>, acc), do: unescape(rest, acc <> <<char>>)
  defp unescape(<<char, rest::binary>>, acc), do: unescape(rest, acc <> <<char>>)
  defp unescape("", acc), do: {:ok, acc}

  defp tag_list("[" <> rest) do
    if String.ends_with?(rest, "]") do
      inner = binary_part(rest, 0, byte_size(rest) - 1)

      tags =
        inner
        |> String.split(",")
        |> Enum.map(&String.trim/1)
        |> Enum.reject(&(&1 == ""))

      if Enum.all?(tags, &(&1 =~ @token)), do: {:ok, tags}, else: :error
    else
      :error
    end
  end

  defp tag_list(_), do: :error

  defp document(title, tags, source, body) do
    body = if String.ends_with?(body, "\n"), do: body, else: body <> "\n"

    IO.iodata_to_binary([
      "---\n",
      "title: ",
      quote_yaml(title),
      "\n",
      "tags: [",
      Enum.join(tags, ", "),
      "]\n",
      "source: ",
      source,
      "\n---\n",
      body
    ])
  end

  defp quote_yaml(text) do
    escaped = text |> String.replace("\\", "\\\\") |> String.replace("\"", "\\\"")
    "\"" <> escaped <> "\""
  end

  defp links(body) do
    ~r/\[\[([a-z0-9-]{1,64})\]\]/
    |> Regex.scan(body)
    |> Enum.map(fn [_, slug] -> slug end)
    |> Enum.uniq()
  end

  defp blob_sha(content) do
    header = "blob #{byte_size(content)}\0"
    :crypto.hash(:sha, header <> content) |> Base.encode16(case: :lower)
  end

  defp message(:create, slug), do: "card: create #{slug}"
  defp message(:update, slug), do: "card: update #{slug}"

  defp path(state, slug), do: Path.join(state.root, slug <> ".md")

  defp read_bytes(state, slug) do
    case File.read(path(state, slug)) do
      {:ok, content} -> content
      _ -> nil
    end
  end

  defp fetch(url, token) do
    with {:ok, owner, repo} <- repo(url),
         {:ok, tip, body} <- download(owner, repo, token),
         {:ok, files} <- unpack(body) do
      tip =
        tip ||
          case remote_tip(owner, repo, token) do
            {:ok, sha} -> sha
            :error -> nil
          end

      {:ok, tip, files}
    else
      _ -> :error
    end
  end

  defp download(owner, repo, token) do
    url = "https://api.github.com/repos/#{owner}/#{repo}/tarball/main"

    case request(:get, url, token, "application/vnd.github+json", redirect: false, decode_body: false) do
      {:ok, %{status: status} = resp} when status in [301, 302, 303, 307, 308] ->
        location = header(resp.headers, "location")
        download_location(location)

      {:ok, %{status: 200, body: body}} when is_binary(body) ->
        {:ok, nil, body}

      {:ok, %{status: status}} ->
        Logger.warning("cards archive http #{status}")
        :error

      {:error, _} ->
        Logger.warning("cards archive transport error")
        :error
    end
  end

  defp download_location(location) when is_binary(location) and location != "" do
    case request_plain(:get, location, decode_body: false, redirect: true) do
      {:ok, %{status: 200, body: body}} when is_binary(body) ->
        {:ok, commit_sha(location), body}

      {:ok, %{status: status}} ->
        Logger.warning("cards archive http #{status}")
        :error

      {:error, _} ->
        Logger.warning("cards archive transport error")
        :error
    end
  end

  defp download_location(_), do: :error

  defp remote_tip(owner, repo, token) do
    url = "https://api.github.com/repos/#{owner}/#{repo}/commits/main"

    case request(:get, url, token, "application/vnd.github.sha", decode_body: false) do
      {:ok, %{status: 200, body: body}} when is_binary(body) ->
        sha = String.trim(body)
        if sha =~ ~r/^[0-9a-f]{40}$/, do: {:ok, sha}, else: remote_tip_json(url, token)

      _ ->
        remote_tip_json(url, token)
    end
  end

  defp remote_tip_json(url, token) do
    case request(:get, url, token, "application/vnd.github+json", []) do
      {:ok, %{status: 200, body: %{"sha" => sha}}} when is_binary(sha) ->
        {:ok, sha}

      {:ok, %{status: status}} ->
        Logger.warning("cards tip http #{status}")
        :error

      {:error, _} ->
        Logger.warning("cards tip transport error")
        :error
    end
  end

  defp commit(owner, repo, token, slug, message, content, sha) do
    url = "https://api.github.com/repos/#{owner}/#{repo}/contents/cards/#{slug}.md"

    payload = %{
      "message" => message,
      "content" => Base.encode64(content),
      "branch" => "main"
    }

    payload = if is_binary(sha), do: Map.put(payload, "sha", sha), else: payload

    case request(:put, url, token, "application/vnd.github+json", json: payload) do
      {:ok, %{status: status, body: body}} when status in [200, 201] and is_map(body) ->
        {:ok, get_in(body, ["commit", "sha"]), get_in(body, ["content", "sha"])}

      {:ok, %{status: status}} when status in [409, 422] ->
        {:error, :conflict}

      {:ok, %{status: status}} ->
        Logger.warning("cards commit http #{status}")
        {:error, :push}

      {:error, _} ->
        Logger.warning("cards commit transport error")
        {:error, :push}
    end
  end

  defp unpack(body) do
    result =
      case body do
        <<0x1F, 0x8B, _::binary>> ->
          :erl_tar.extract({:binary, body}, [:memory, :compressed])

        _ ->
          :erl_tar.extract({:binary, body}, [:memory])
      end

    case result do
      {:ok, files} -> {:ok, card_files(files)}
      _ -> :error
    end
  end

  defp card_files(files) do
    Enum.flat_map(files, fn {name, content} ->
      name = to_string(name)
      content = if is_binary(content), do: content, else: IO.iodata_to_binary(content)

      case Regex.run(~r/(?:^|\/)cards\/([a-z0-9-]{1,64})\.md$/, name) do
        [_, slug] -> [{slug, content}]
        _ -> []
      end
    end)
  end

  defp request(method, url, token, accept, extra) do
    headers = [
      {"authorization", "Bearer " <> token},
      {"accept", accept},
      {"user-agent", "clinker-cards"},
      {"x-github-api-version", "2022-11-28"}
    ]

    request_plain(method, url, Keyword.merge([headers: headers], extra))
  end

  defp request_plain(method, url, extra) do
    opts =
      [method: method, url: url, retry: false, receive_timeout: 60_000]
      |> Keyword.merge(extra)
      |> Keyword.merge(Application.get_env(:assistant, :cards_req, []))

    Req.request(opts)
  end

  defp header(headers, name) when is_map(headers) do
    headers
    |> Map.get(name, Map.get(headers, String.to_charlist(name), []))
    |> List.wrap()
    |> List.first()
  end

  defp header(headers, name) when is_list(headers) do
    Enum.find_value(headers, fn
      {key, value} ->
        if String.downcase(to_string(key)) == name, do: List.wrap(value) |> List.first()

      _ ->
        nil
    end)
  end

  defp commit_sha(location) do
    base = location |> URI.parse() |> Map.get(:path, "") |> Path.basename()
    if base =~ ~r/^[0-9a-f]{40}$/, do: base, else: nil
  end

  defp repo(url) when is_binary(url) do
    path = url |> URI.parse() |> Map.get(:path, "") |> String.trim("/")

    case String.split(path, "/", trim: true) do
      [owner, name | _] ->
        {:ok, owner, String.trim_trailing(name, ".git")}

      _ ->
        :error
    end
  end

  defp repo(_), do: :error

  defp credentials do
    cfg = config()

    case {cfg[:repo_url], cfg[:git_token]} do
      {url, token} when is_binary(url) and is_binary(token) and url != "" and token != "" ->
        {:ok, String.trim(url), String.trim(token)}

      _ ->
        :error
    end
  end

  defp config, do: Application.get_env(:assistant, :cards, %{})

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
