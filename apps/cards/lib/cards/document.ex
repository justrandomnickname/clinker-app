defmodule Cards.Document do
  @token ~r/^[a-z0-9-]{1,64}$/

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

  def build(title, tags, source, body) do
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

  def links(body) when is_binary(body) do
    ~r/\[\[([a-z0-9-]{1,64})\]\]/
    |> Regex.scan(body)
    |> Enum.map(fn [_, slug] -> slug end)
    |> Enum.uniq()
  end

  def links(_), do: []

  def blob_sha(content) do
    header = "blob #{byte_size(content)}\0"
    :crypto.hash(:sha, header <> content) |> Base.encode16(case: :lower)
  end

  defp split_header(rest) do
    {header, tail} = Enum.split_while(String.split(rest, "\n"), &(&1 != "---"))

    case tail do
      ["---" | body] -> {:ok, header, Enum.join(body, "\n")}
      _ -> :error
    end
  end

  defp decode_header(lines, body) do
    lines
    |> Enum.reduce_while({:ok, %{}}, fn line, {:ok, acc} ->
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

  defp quote_yaml(text) do
    escaped = text |> String.replace("\\", "\\\\") |> String.replace("\"", "\\\"")
    "\"" <> escaped <> "\""
  end
end
