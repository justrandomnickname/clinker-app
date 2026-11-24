defmodule Cards.Write do
  alias Cards.{Cache, Document, Index, Remote, Rules}

  def run(%{status: :ready} = state, op, fields) do
    case prepare(state, op, fields) do
      {:ok, state, content} ->
        case push(state, op, fields.slug, content, false) do
          {:ok, state} -> {:ok, %{slug: fields.slug}, state}
          {:error, reason, state} -> {:error, reason, state}
        end

      {:error, reason, state} ->
        {:error, reason, state}
    end
  end

  def run(state, _op, _fields), do: {:error, :unavailable, state}

  defp prepare(state, op, fields) do
    before = Cache.read(state.root, fields.slug)

    case sync(state) do
      {:ok, state} ->
        after_bytes = Cache.read(state.root, fields.slug)

        cond do
          op == :create and Index.has?(state.cards, fields.slug) ->
            {:error, :exists, state}

          op == :update and not Index.has?(state.cards, fields.slug) ->
            {:error, :missing, state}

          before != after_bytes ->
            {:error, :conflict, state}

          true ->
            case encode(op, fields, state) do
              {:ok, content} -> {:ok, state, content}
              :invalid -> {:error, :invalid, state}
            end
        end

      :error ->
        {:error, :unavailable, state}
    end
  end

  defp sync(%{tip: tip} = state) do
    with {:ok, url, token} <- Remote.credentials(),
         {:ok, owner, name} <- Remote.repo(url) do
      case Remote.tip(owner, name, token) do
        {:ok, ^tip} -> {:ok, state}
        {:ok, _remote} -> fetch_into(state, url, token)
        :empty -> {:ok, state}
        :error -> :error
      end
    else
      _ -> :error
    end
  end

  defp fetch_into(state, url, token) do
    case Remote.fetch(url, token) do
      {:ok, tip, files} ->
        Cache.install(state.root, files)
        {cards, by_tag} = Index.build(files)
        {:ok, %{state | status: :ready, tip: tip, cards: cards, by_tag: by_tag}}

      :error ->
        :error
    end
  end

  defp encode(:create, fields, _state) do
    {:ok, Document.build(fields.title, fields.tags, fields.source, fields.body)}
  end

  defp encode(:update, fields, state) do
    case Index.source(state.cards, fields.slug) do
      source when is_binary(source) ->
        if Rules.token?(source) do
          {:ok, Document.build(fields.title, fields.tags, source, fields.body)}
        else
          :invalid
        end

      _ ->
        :invalid
    end
  end

  defp push(state, op, slug, content, retried?) do
    with {:ok, url, token} <- Remote.credentials(),
         {:ok, owner, name} <- Remote.repo(url) do
      sha = if op == :update, do: Index.blob(state.cards, slug), else: nil

      case Remote.commit(owner, name, token, slug, message(op, slug), content, sha) do
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
    before = Cache.read(state.root, slug)

    case Remote.credentials() do
      {:ok, url, token} ->
        case fetch_into(state, url, token) do
          {:ok, state} ->
            cond do
              op == :create and Index.has?(state.cards, slug) ->
                {:error, :exists, state}

              op == :update and not Index.has?(state.cards, slug) ->
                {:error, :missing, state}

              Cache.read(state.root, slug) != before ->
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
    case Remote.credentials() do
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
    Cache.write(state.root, slug, content)
    {cards, by_tag} = Index.put(state.cards, state.by_tag, slug, content, blob)
    %{state | cards: cards, by_tag: by_tag, tip: tip || state.tip, status: :ready}
  end

  defp message(:create, slug), do: "card: create #{slug}"
  defp message(:update, slug), do: "card: update #{slug}"
end
