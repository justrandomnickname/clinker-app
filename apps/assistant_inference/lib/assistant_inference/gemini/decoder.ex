defmodule AssistantInference.Gemini.Decoder do
  def take(buffer, chunk) when is_binary(buffer) and is_binary(chunk) do
    {lines, rest} = split_lines(buffer <> chunk, [])
    {Enum.flat_map(lines, &parse_line/1), rest}
  end

  defp split_lines(text, acc) do
    case String.split(text, "\n", parts: 2) do
      [rest] ->
        {Enum.reverse(acc), rest}

      [line, rest] ->
        split_lines(rest, [String.trim_trailing(line, "\r") | acc])
    end
  end

  defp parse_line("data: " <> data), do: decode(String.trim(data))
  defp parse_line("data:" <> data), do: decode(String.trim(data))
  defp parse_line(_), do: []

  defp decode(""), do: []
  defp decode("[DONE]"), do: []

  defp decode(json) do
    case Jason.decode(json) do
      {:ok, payload} -> events(payload)
      _ -> [:invalid_json]
    end
  end

  defp events(%{"error" => _}), do: [:api_error]

  defp events(payload) when is_map(payload) do
    text_events =
      payload
      |> parts()
      |> Enum.flat_map(&part_event/1)

    case usage(payload["usageMetadata"]) do
      nil -> text_events
      {prompt, eval} -> text_events ++ [{:usage, prompt, eval}]
    end
  end

  defp events(_), do: []

  defp parts(payload) do
    get_in(payload, ["candidates", Access.at(0), "content", "parts"]) || []
  end

  defp part_event(%{"thought" => true, "text" => text}) when is_binary(text) and text != "" do
    [{:thinking, text}]
  end

  defp part_event(%{"text" => text}) when is_binary(text) and text != "" do
    [{:text, text}]
  end

  defp part_event(_), do: []

  defp usage(nil), do: nil

  defp usage(meta) when is_map(meta) do
    prompt = count(meta["promptTokenCount"])
    eval = count(meta["candidatesTokenCount"]) + count(meta["thoughtsTokenCount"])
    {prompt, eval}
  end

  defp count(n) when is_integer(n) and n >= 0, do: n
  defp count(n) when is_float(n) and n >= 0, do: round(n)
  defp count(_), do: 0
end
