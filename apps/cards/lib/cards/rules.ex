defmodule Cards.Rules do
  @body_max 32 * 1024
  @token ~r/^[a-z0-9-]{1,64}$/

  def token?(text) when is_binary(text), do: text =~ @token
  def token?(_), do: false

  def clean_tags(tags) when is_list(tags) do
    tags
    |> Enum.filter(&is_binary/1)
    |> Enum.map(&String.downcase/1)
    |> Enum.filter(&token?/1)
    |> Enum.uniq()
  end

  def normalize_body(body) when is_binary(body) do
    body |> String.replace("\r\n", "\n") |> String.replace("\r", "\n")
  end

  def normalize_body(body), do: body

  def cast_create(slug, title, tags, source, body) do
    title = trim(title)
    body = normalize_body(body)

    if validate(slug, title, tags, source, body) == :ok do
      {:ok, %{slug: slug, title: title, tags: tags, source: source, body: body}}
    else
      :error
    end
  end

  def cast_update(slug, title, tags, body) do
    title = trim(title)
    body = normalize_body(body)

    with :ok <- validate_slug(slug),
         :ok <- validate_title(title, slug),
         :ok <- validate_tags(tags, title),
         :ok <- validate_body(body) do
      {:ok, %{slug: slug, title: title, tags: tags, body: body}}
    else
      :error -> :error
    end
  end

  def validate(slug, title, tags, source, body) do
    with :ok <- validate_slug(slug),
         :ok <- validate_title(title, slug),
         :ok <- validate_tags(tags, title),
         :ok <- validate_source(source),
         :ok <- validate_body(body) do
      :ok
    else
      :error -> :error
    end
  end

  defp trim(title) when is_binary(title), do: String.trim(title)
  defp trim(title), do: title

  defp validate_slug(slug) when is_binary(slug) do
    if token?(slug), do: :ok, else: :error
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

  defp valid_tag?(tag, title), do: token?(tag) and tag != title

  defp validate_source(source), do: if(token?(source), do: :ok, else: :error)

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
end
