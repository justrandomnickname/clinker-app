defmodule AssistantWeb.Shared.ContextSlug do
  @max 64
  @reserved "no_context"

  @letters %{
    "а" => "a",
    "б" => "b",
    "в" => "v",
    "г" => "g",
    "д" => "d",
    "е" => "e",
    "ё" => "e",
    "ж" => "zh",
    "з" => "z",
    "и" => "i",
    "й" => "y",
    "к" => "k",
    "л" => "l",
    "м" => "m",
    "н" => "n",
    "о" => "o",
    "п" => "p",
    "р" => "r",
    "с" => "s",
    "т" => "t",
    "у" => "u",
    "ф" => "f",
    "х" => "h",
    "ц" => "ts",
    "ч" => "ch",
    "ш" => "sh",
    "щ" => "sch",
    "ъ" => "",
    "ы" => "y",
    "ь" => "",
    "э" => "e",
    "ю" => "yu",
    "я" => "ya"
  }

  def canonical(text) when is_binary(text) do
    slug =
      text
      |> String.trim()
      |> String.downcase()
      |> String.replace(~r/\s+/u, "_")
      |> transliterate()
      |> String.replace(~r/[^a-z0-9_]/, "")
      |> String.replace(~r/_+/, "_")
      |> String.trim("_")
      |> String.slice(0, @max)
      |> String.trim("_")

    cond do
      slug == "" -> :error
      slug == @reserved -> :reserved
      true -> {:ok, slug}
    end
  end

  defp transliterate(text) do
    text
    |> String.graphemes()
    |> Enum.map_join(fn letter -> Map.get(@letters, letter, letter) end)
  end
end
