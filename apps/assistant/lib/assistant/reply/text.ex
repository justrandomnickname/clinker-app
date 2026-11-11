defmodule Assistant.Reply.Text do
  @title_max 48
  @overlap_min 25

  def clip_title(text) when is_binary(text) do
    text = String.trim(text)

    cond do
      text == "" -> "Новый чат"
      String.length(text) <= @title_max -> text
      true -> clip_at(text, @title_max)
    end
  end

  def remainder(existing, incoming) when is_binary(existing) and is_binary(incoming) do
    max_len = min(String.length(existing), String.length(incoming))

    if max_len < @overlap_min do
      incoming
    else
      case longest_match(existing, incoming, @overlap_min, max_len, 0) do
        match when match >= @overlap_min ->
          String.slice(incoming, match, String.length(incoming) - match)

        _ ->
          incoming
      end
    end
  end

  def full_text(state), do: state.base_text <> remainder(state.base_text, state.new_text)

  def full_thinking(state), do: state.base_thinking <> state.new_thinking

  defp clip_at(text, max) do
    slice = String.slice(text, 0, max)
    next = String.slice(text, max, 1)

    if next == " " or String.ends_with?(slice, " ") do
      String.trim_trailing(slice)
    else
      case Enum.drop(String.split(slice, " "), -1) do
        [] -> slice
        kept -> Enum.join(kept, " ")
      end
    end
  end

  defp longest_match(_existing, _incoming, low, high, best) when low > high, do: best

  defp longest_match(existing, incoming, low, high, best) do
    mid = div(low + high, 2)

    if suffix_prefix?(existing, incoming, mid) do
      longest_match(existing, incoming, mid + 1, high, mid)
    else
      longest_match(existing, incoming, low, mid - 1, best)
    end
  end

  defp suffix_prefix?(existing, incoming, len) do
    String.starts_with?(incoming, String.slice(existing, -len, len))
  end
end
