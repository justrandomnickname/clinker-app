ExUnit.start()

ExUnit.after_suite(fn _ ->
  case Application.fetch_env(:assistant, Assistant.Repo) do
    {:ok, config} ->
      path = config[:database]
      Enum.each([path, path <> "-wal", path <> "-shm"], &File.rm/1)

    :error ->
      :ok
  end
end)
