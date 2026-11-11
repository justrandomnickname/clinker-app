ExUnit.start()

ExUnit.after_suite(fn _ ->
  path = Application.fetch_env!(:assistant, Assistant.Repo)[:database]
  Enum.each([path, path <> "-wal", path <> "-shm"], &File.rm/1)
end)
