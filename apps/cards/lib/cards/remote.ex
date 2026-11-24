defmodule Cards.Remote do
  require Logger

  def credentials do
    cfg = config()

    case {cfg[:repo_url], cfg[:git_token]} do
      {url, token} when is_binary(url) and is_binary(token) and url != "" and token != "" ->
        {:ok, String.trim(url), String.trim(token)}

      _ ->
        :error
    end
  end

  def repo(url) when is_binary(url) do
    path = url |> URI.parse() |> Map.get(:path, "") |> String.trim("/")

    case String.split(path, "/", trim: true) do
      [owner, name | _] ->
        {:ok, owner, String.trim_trailing(name, ".git")}

      _ ->
        :error
    end
  end

  def repo(_), do: :error

  def fetch(url, token) do
    with {:ok, owner, name} <- repo(url) do
      case download(owner, name, token) do
        :empty ->
          {:ok, nil, []}

        {:ok, tip, body} ->
          case unpack(body) do
            {:ok, files} -> {:ok, tip || known_tip(owner, name, token), files}
            :error -> :error
          end

        {:files, files} ->
          {:ok, known_tip(owner, name, token), files}

        :error ->
          :error
      end
    else
      _ -> :error
    end
  end

  def tip(owner, name, token) do
    url = "https://api.github.com/repos/#{owner}/#{name}/commits/main"

    case request(:get, url, token, "application/vnd.github.sha", decode_body: false) do
      {:ok, %{status: 200, body: body}} when is_binary(body) ->
        sha = String.trim(body)
        if sha =~ ~r/^[0-9a-f]{40}$/, do: {:ok, sha}, else: tip_json(owner, name, token)

      _ ->
        tip_json(owner, name, token)
    end
  end

  def commit(owner, name, token, slug, message, content, sha) do
    url = "https://api.github.com/repos/#{owner}/#{name}/contents/cards/#{slug}.md"

    payload = %{
      "message" => message,
      "content" => Base.encode64(content),
      "branch" => "main"
    }

    payload = if is_binary(sha), do: Map.put(payload, "sha", sha), else: payload

    case request(:put, url, token, "application/vnd.github+json", json: payload) do
      {:ok, %{status: status, body: body}} when status in [200, 201] and is_map(body) ->
        {:ok, get_in(body, ["commit", "sha"]), get_in(body, ["content", "sha"])}

      {:ok, %{status: status}} when status in [409, 422] ->
        {:error, :conflict}

      {:ok, %{status: status, body: body}} ->
        log_github("commit", status, body)
        {:error, :push}

      {:error, _} ->
        Logger.warning("cards commit transport error")
        {:error, :push}
    end
  end

  defp known_tip(owner, name, token) do
    case tip(owner, name, token) do
      {:ok, sha} -> sha
      _ -> nil
    end
  end

  defp download(owner, name, token) do
    case archive(owner, name, token) do
      :error -> via_contents(owner, name, token)
      other -> other
    end
  end

  defp archive(owner, name, token) do
    url = "https://api.github.com/repos/#{owner}/#{name}/tarball/main"

    case request(:get, url, token, "application/vnd.github+json",
           redirect: false,
           decode_body: false
         ) do
      {:ok, %{status: status} = resp} when status in [301, 302, 303, 307, 308] ->
        download_location(header(resp.headers, "location"), token)

      {:ok, %{status: 200, body: body}} when is_binary(body) ->
        {:ok, nil, body}

      {:ok, %{status: 404, body: body}} ->
        missing_archive(owner, name, token, body)

      {:ok, %{status: status, body: body}} ->
        log_github("archive", status, body)
        :error

      {:error, _} ->
        Logger.warning("cards archive transport error")
        :error
    end
  end

  defp via_contents(owner, name, token) do
    url = "https://api.github.com/repos/#{owner}/#{name}/contents/cards?ref=main"

    case request(:get, url, token, "application/vnd.github+json", []) do
      {:ok, %{status: 200, body: entries}} when is_list(entries) ->
        {:files, read_entries(owner, name, token, entries)}

      {:ok, %{status: 404}} ->
        if repo_visible?(owner, name, token), do: :empty, else: :error

      {:ok, %{status: status, body: body}} ->
        log_github("cards", status, body)
        :error

      {:error, _} ->
        Logger.warning("cards directory transport error")
        :error
    end
  end

  defp read_entries(owner, name, token, entries) do
    Enum.flat_map(entries, fn
      %{"type" => "file", "name" => filename} ->
        case Regex.run(~r/^([a-z0-9-]{1,64})\.md$/, filename) do
          [_, slug] ->
            case file_body(owner, name, token, slug) do
              {:ok, content} -> [{slug, content}]
              :error -> []
            end

          _ ->
            []
        end

      _ ->
        []
    end)
  end

  defp file_body(owner, name, token, slug) do
    url = "https://api.github.com/repos/#{owner}/#{name}/contents/cards/#{slug}.md"

    case request(:get, url, token, "application/vnd.github+json", []) do
      {:ok, %{status: 200, body: %{"content" => content, "encoding" => "base64"}}}
      when is_binary(content) ->
        case Base.decode64(content, ignore: :whitespace) do
          {:ok, binary} -> {:ok, binary}
          :error -> :error
        end

      {:ok, %{status: status, body: body}} ->
        log_github("file", status, body)
        :error

      {:error, _} ->
        :error
    end
  end

  defp repo_visible?(owner, name, token) do
    url = "https://api.github.com/repos/#{owner}/#{name}"

    match?({:ok, %{status: 200}}, request(:get, url, token, "application/vnd.github+json", []))
  end

  defp empty_repo?(owner, name, token) do
    url = "https://api.github.com/repos/#{owner}/#{name}"

    case request(:get, url, token, "application/vnd.github+json", []) do
      {:ok, %{status: 200, body: %{"size" => 0}}} -> true
      _ -> false
    end
  end

  defp missing_archive(owner, name, token, archive_body) do
    url = "https://api.github.com/repos/#{owner}/#{name}"

    case request(:get, url, token, "application/vnd.github+json", []) do
      {:ok, %{status: 200, body: %{"size" => 0}}} ->
        :empty

      {:ok, %{status: 200, body: %{"default_branch" => branch, "size" => size}}}
      when is_binary(branch) and branch != "main" and is_integer(size) and size > 0 ->
        download_ref(owner, name, token, branch)

      {:ok, %{status: 200}} ->
        log_github("archive", 404, archive_body)
        :error

      {:ok, %{status: status, body: body}} ->
        log_github("repo", status, body)
        :error

      {:error, _} ->
        Logger.warning("cards repo transport error")
        :error
    end
  end

  defp download_ref(owner, name, token, branch) do
    url = "https://api.github.com/repos/#{owner}/#{name}/tarball/#{branch}"

    case request(:get, url, token, "application/vnd.github+json",
           redirect: false,
           decode_body: false
         ) do
      {:ok, %{status: status} = resp} when status in [301, 302, 303, 307, 308] ->
        download_location(header(resp.headers, "location"), token)

      {:ok, %{status: 200, body: body}} when is_binary(body) ->
        {:ok, nil, body}

      {:ok, %{status: status, body: body}} ->
        log_github("archive", status, body)
        :error

      {:error, _} ->
        Logger.warning("cards archive transport error")
        :error
    end
  end

  defp download_location(location, token) when is_binary(location) and location != "" do
    headers = [
      {"authorization", "Bearer " <> token},
      {"user-agent", "clinker-cards"},
      {"accept", "application/vnd.github+json"}
    ]

    case request_plain(:get, location, headers: headers, decode_body: false, redirect: true) do
      {:ok, %{status: 200, body: body}} when is_binary(body) ->
        {:ok, commit_sha(location), body}

      {:ok, %{status: status, body: body}} ->
        log_github("archive", status, body)
        :error

      {:error, _} ->
        Logger.warning("cards archive transport error")
        :error
    end
  end

  defp download_location(_location, _token), do: :error

  defp tip_json(owner, name, token) do
    url = "https://api.github.com/repos/#{owner}/#{name}/commits/main"

    case request(:get, url, token, "application/vnd.github+json", []) do
      {:ok, %{status: 200, body: %{"sha" => sha}}} when is_binary(sha) ->
        {:ok, sha}

      {:ok, %{status: 409}} ->
        :empty

      {:ok, %{status: 404}} ->
        if empty_repo?(owner, name, token), do: :empty, else: :error

      {:ok, %{status: status, body: body}} ->
        log_github("tip", status, body)
        :error

      {:error, _} ->
        Logger.warning("cards tip transport error")
        :error
    end
  end

  defp unpack(body) do
    result =
      case body do
        <<0x1F, 0x8B, _::binary>> ->
          :erl_tar.extract({:binary, body}, [:memory, :compressed])

        _ ->
          :erl_tar.extract({:binary, body}, [:memory])
      end

    case result do
      {:ok, files} -> {:ok, card_files(files)}
      _ -> :error
    end
  end

  defp card_files(files) do
    Enum.flat_map(files, fn {filename, content} ->
      filename = to_string(filename)
      content = if is_binary(content), do: content, else: IO.iodata_to_binary(content)

      case Regex.run(~r/(?:^|\/)cards\/([a-z0-9-]{1,64})\.md$/, filename) do
        [_, slug] -> [{slug, content}]
        _ -> []
      end
    end)
  end

  defp log_github(what, status, body) do
    message =
      case body do
        text when is_binary(text) ->
          case Jason.decode(text) do
            {:ok, %{"message" => message}} when is_binary(message) -> message
            _ -> ""
          end

        %{"message" => message} when is_binary(message) ->
          message

        _ ->
          ""
      end

    Logger.warning("cards #{what} http #{status} #{String.slice(message, 0, 120)}")
  end

  defp request(method, url, token, accept, extra) do
    headers = [
      {"authorization", "Bearer " <> token},
      {"accept", accept},
      {"user-agent", "clinker-cards"},
      {"x-github-api-version", "2022-11-28"}
    ]

    request_plain(method, url, Keyword.merge([headers: headers], extra))
  end

  defp request_plain(method, url, extra) do
    opts =
      [method: method, url: url, retry: false, receive_timeout: 60_000]
      |> Keyword.merge(extra)
      |> Keyword.merge(Application.get_env(:cards, :req, []))

    Req.request(opts)
  end

  defp header(headers, name) when is_map(headers) do
    Enum.find_value(headers, fn {key, value} ->
      if String.downcase(to_string(key)) == name, do: header_text(value)
    end)
  end

  defp header(headers, name) when is_list(headers) do
    Enum.find_value(headers, fn
      {key, value} ->
        if String.downcase(to_string(key)) == name, do: header_text(value)

      _ ->
        nil
    end)
  end

  defp header_text(value) when is_binary(value), do: value
  defp header_text([value | _]) when is_binary(value), do: value
  defp header_text(value) when is_list(value), do: List.to_string(value)
  defp header_text(_), do: nil

  defp commit_sha(location) do
    base = location |> URI.parse() |> Map.get(:path, "") |> Path.basename()
    if base =~ ~r/^[0-9a-f]{40}$/, do: base, else: nil
  end

  defp config, do: Application.get_env(:cards, :repo, %{})
end
