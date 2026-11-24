defmodule Cards.Index do
  alias Cards.{Document, Rules}

  def build(files) do
    Enum.reduce(files, {%{}, %{}}, fn {slug, content}, {cards, by_tag} ->
      card = one(slug, content)
      {Map.put(cards, slug, card), add_tags(by_tag, slug, card.tags)}
    end)
  end

  def put(cards, by_tag, slug, content, blob) do
    card = one(slug, content)
    card = if is_binary(blob), do: %{card | blob: blob}, else: card
    old = cards[slug]
    cards = Map.put(cards, slug, card)
    by_tag = retag(by_tag, slug, (old && old.tags) || [], card.tags)
    {cards, by_tag}
  end

  def headers(cards, by_tag, tags) do
    cards
    |> slugs(by_tag, tags)
    |> Enum.map(fn slug ->
      card = Map.fetch!(cards, slug)

      %{
        slug: slug,
        title: card.title,
        tags: card.tags,
        source: card.source,
        broken: card.broken
      }
    end)
  end

  def present(cards, slug, content) do
    case Map.get(cards, slug) do
      nil ->
        {:error, :missing}

      card ->
        {body, broken} =
          case Document.parse(content) do
            {:ok, fields} -> {fields.body, card.broken}
            :error -> {content, true}
          end

        {:ok,
         %{
           slug: slug,
           title: card.title,
           tags: card.tags,
           source: card.source,
           body: body,
           outgoing: card.outgoing,
           incoming: incoming(cards, slug),
           broken: broken
         }}
    end
  end

  def has?(cards, slug), do: Map.has_key?(cards, slug)

  def source(cards, slug) do
    case cards[slug] do
      %{source: source} when is_binary(source) -> source
      _ -> nil
    end
  end

  def blob(cards, slug), do: cards[slug].blob

  defp one(slug, content) do
    blob = Document.blob_sha(content)

    parsed =
      if String.valid?(content) do
        Document.parse(content)
      else
        :error
      end

    case parsed do
      {:ok, fields} ->
        if Rules.validate(slug, fields.title, fields.tags, fields.source, fields.body) == :ok do
          %{
            title: fields.title,
            tags: fields.tags,
            source: fields.source,
            outgoing: Document.links(fields.body),
            broken: false,
            blob: blob
          }
        else
          broken(fields, blob)
        end

      :error ->
        %{title: nil, tags: [], source: nil, outgoing: [], broken: true, blob: blob}
    end
  end

  defp broken(fields, blob) do
    %{
      title: fields.title,
      tags: fields.tags,
      source: fields.source,
      outgoing: [],
      broken: true,
      blob: blob
    }
  end

  defp incoming(cards, slug) do
    cards
    |> Enum.filter(fn {other, card} -> other != slug and slug in card.outgoing end)
    |> Enum.map(&elem(&1, 0))
    |> Enum.sort()
  end

  defp slugs(cards, _by_tag, []), do: cards |> Map.keys() |> Enum.sort()

  defp slugs(_cards, by_tag, tags) do
    tags
    |> Enum.map(fn tag -> Map.get(by_tag, tag, MapSet.new()) end)
    |> Enum.reduce(&MapSet.intersection/2)
    |> MapSet.to_list()
    |> Enum.sort()
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
end
