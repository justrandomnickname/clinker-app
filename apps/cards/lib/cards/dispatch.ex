defmodule Cards.Dispatch do
  alias Cards.Rules

  def call(name, nil) when is_binary(name), do: call(name, %{})
  def call("list_cards", args), do: list(stringify(args))
  def call("get_card", args), do: get(stringify(args))
  def call("create_card", args), do: create(stringify(args))
  def call("update_card", args), do: update(stringify(args))
  def call(_, _), do: :invalid

  defp list(args) do
    cond do
      args == %{} ->
        {:list, []}

      match?(%{"tags" => tags} when is_list(tags), args) and map_size(args) == 1 ->
        if Enum.all?(args["tags"], &is_binary/1) and Rules.clean_tags(args["tags"]) == args["tags"] do
          {:list, args["tags"]}
        else
          :invalid
        end

      true ->
        :invalid
    end
  end

  defp get(%{"slug" => slug} = args) when map_size(args) == 1 do
    if Rules.token?(slug), do: {:get, slug}, else: :invalid
  end

  defp get(_), do: :invalid

  defp create(args) when is_map(args) do
    fields = ~w(slug title tags source body)

    if Enum.sort(Map.keys(args)) == Enum.sort(fields) do
      case Rules.cast_create(args["slug"], args["title"], args["tags"], args["source"], args["body"]) do
        {:ok, fields} -> {:create, fields}
        :error -> :invalid
      end
    else
      :invalid
    end
  end

  defp create(_), do: :invalid

  defp update(args) when is_map(args) do
    fields = ~w(slug title tags body)

    if Enum.sort(Map.keys(args)) == Enum.sort(fields) do
      case Rules.cast_update(args["slug"], args["title"], args["tags"], args["body"]) do
        {:ok, fields} -> {:update, fields}
        :error -> :invalid
      end
    else
      :invalid
    end
  end

  defp update(_), do: :invalid

  defp stringify(args) when is_map(args) do
    Map.new(args, fn {key, value} -> {to_string(key), value} end)
  end

  defp stringify(_), do: :bad
end
