defmodule Cards.Cache do
  def install(root, files) do
    File.mkdir_p!(root)
    keep = MapSet.new(Enum.map(files, fn {slug, _} -> slug <> ".md" end))

    case File.ls(root) do
      {:ok, names} ->
        Enum.each(names, fn name ->
          if String.ends_with?(name, ".md") and name not in keep do
            File.rm(Path.join(root, name))
          end
        end)

      _ ->
        :ok
    end

    Enum.each(files, fn {slug, content} ->
      File.write!(path(root, slug), content)
    end)

    :ok
  end

  def write(root, slug, content) do
    File.mkdir_p!(root)
    File.write!(path(root, slug), content)
  end

  def read(root, slug) do
    case File.read(path(root, slug)) do
      {:ok, content} -> content
      _ -> nil
    end
  end

  defp path(root, slug), do: Path.join(root, slug <> ".md")
end
