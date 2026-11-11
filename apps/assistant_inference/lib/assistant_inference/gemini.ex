defmodule AssistantInference.Gemini do
  require Logger

  alias AssistantInference.Gemini.Decoder

  @idle_ms 120_000

  def model do
    Map.fetch!(config(), :model)
  end

  def key_set? do
    match?({:ok, _}, fetch_key())
  end

  def put_key(key) when is_binary(key) do
    if env_key() do
      :ok
    else
      File.write(key_path(), String.trim(key))
    end
  end

  def ready?(model) when is_binary(model) do
    with {:ok, key} <- fetch_key(),
         {:ok, models} <- fetch_models(key),
         true <- listed?(models, model) do
      true
    else
      _ -> false
    end
  end

  def ready?(_), do: false

  def context_limit do
    with {:ok, key} <- fetch_key(),
         {:ok, models} <- fetch_models(key),
         {:ok, id} <- model_id(model()) do
      token_limit(models, id)
    else
      _ -> nil
    end
  end

  def balance, do: nil

  def token_limit(models, id) when is_list(models) and is_binary(id) do
    case Enum.find(models, &name_matches?(&1["name"] || "", id)) do
      %{"inputTokenLimit" => limit} when is_integer(limit) and limit > 0 -> limit
      _ -> nil
    end
  end

  def stream(request, opts) do
    parent = Keyword.fetch!(opts, :parent)
    ref = Keyword.fetch!(opts, :ref)
    deadline = Keyword.fetch!(opts, :deadline)
    Process.monitor(parent)

    with {:ok, key} <- fetch_key(),
         {:ok, model} <- model_id(model()),
         {:ok, resp} <- post(model, key, request) do
      pump(resp, "", parent, ref, deadline, {0, 0}, false)
    else
      :error -> {:error, :unavailable}
      {:error, reason} -> {:error, reason}
    end
  end

  defp post(model, key, request) do
    result =
      [method: :post, url: stream_url(model), json: body(request)]
      |> Keyword.merge(common_opts(key))
      |> Keyword.merge(into: :self, receive_timeout: @idle_ms)
      |> Req.request()

    case result do
      {:ok, %{status: status} = resp} when status in 200..299 ->
        {:ok, resp}

      {:ok, %{status: status} = resp} ->
        _ = Req.cancel_async_response(resp)
        Logger.warning("gemini stream http #{status}")
        {:error, {:http, status}}

      {:error, _} ->
        Logger.warning("gemini stream transport error")
        {:error, :transport}
    end
  end

  defp body(%{system: system, contents: contents}) do
    payload = %{
      "contents" => contents,
      "generationConfig" => %{"thinkingConfig" => %{"includeThoughts" => true}}
    }

    if is_binary(system) and system != "" do
      Map.put(payload, "systemInstruction", %{"parts" => [%{"text" => system}]})
    else
      payload
    end
  end

  defp pump(resp, buffer, parent, ref, deadline, usage, saw?) do
    timeout = idle_timeout(deadline)

    if timeout <= 0 do
      cancel(resp)
      {:error, :timeout}
    else
      receive do
        {:cancel, ^ref} ->
          cancel(resp)
          {:error, :cancelled}

        {:DOWN, _, :process, ^parent, _} ->
          cancel(resp)
          {:error, :cancelled}

        message ->
          handle_message(resp, message, buffer, parent, ref, deadline, usage, saw?)
      after
        timeout ->
          cancel(resp)
          {:error, :timeout}
      end
    end
  end

  defp handle_message(resp, message, buffer, parent, ref, deadline, usage, saw?) do
    case Req.parse_message(resp, message) do
      {:ok, parts} ->
        case consume(parts, buffer, parent, ref, usage, saw?) do
          {:done, usage, true} ->
            {:ok, usage}

          {:done, _usage, false} ->
            {:ok, {0, 0}}

          {:cont, buffer, usage, saw?} ->
            pump(resp, buffer, parent, ref, deadline, usage, saw?)

          {:error, reason} ->
            cancel(resp)
            {:error, reason}
        end

      {:error, _} ->
        cancel(resp)
        {:error, :transport}

      :unknown ->
        pump(resp, buffer, parent, ref, deadline, usage, saw?)
    end
  end

  defp consume(parts, buffer, parent, ref, usage, saw?) do
    Enum.reduce_while(parts, {:cont, buffer, usage, saw?}, fn part,
                                                              {:cont, buffer, usage, saw?} ->
      case part do
        {:data, data} ->
          {events, rest} = Decoder.take(buffer, data)

          case forward(events, parent, ref, usage, saw?) do
            {:ok, usage, saw?} -> {:cont, {:cont, rest, usage, saw?}}
            {:error, reason} -> {:halt, {:error, reason}}
          end

        :done ->
          {:halt, {:done, usage, saw?}}

        _ ->
          {:cont, {:cont, buffer, usage, saw?}}
      end
    end)
  end

  defp forward(events, parent, ref, usage, saw?) do
    Enum.reduce_while(events, {:ok, usage, saw?}, fn event, {:ok, usage, saw?} ->
      case event do
        :invalid_json ->
          {:halt, {:error, :invalid_response}}

        :api_error ->
          {:halt, {:error, :api_error}}

        {:text, text} ->
          send(parent, {:inference_chunk, ref, {:text, text}})
          {:cont, {:ok, usage, saw?}}

        {:thinking, text} ->
          send(parent, {:inference_chunk, ref, {:thinking, text}})
          {:cont, {:ok, usage, saw?}}

        {:usage, prompt, eval} ->
          send(parent, {:inference_chunk, ref, {:usage, prompt, eval}})
          {:cont, {:ok, {prompt, eval}, true}}
      end
    end)
  end

  defp cancel(resp) do
    _ = Req.cancel_async_response(resp)
    :ok
  end

  defp idle_timeout(deadline) do
    remaining = deadline - System.monotonic_time(:millisecond)
    min(@idle_ms, max(remaining, 0))
  end

  defp fetch_models(key, token \\ nil, acc \\ [], left \\ 5)

  defp fetch_models(_key, _token, acc, 0), do: {:ok, acc}

  defp fetch_models(key, token, acc, left) do
    params = [pageSize: 100]

    params =
      if is_binary(token) and token != "",
        do: Keyword.put(params, :pageToken, token),
        else: params

    result =
      [method: :get, url: models_url(), params: params, receive_timeout: 10_000]
      |> Keyword.merge(common_opts(key))
      |> Req.request()

    case result do
      {:ok, %{status: 200, body: body}} when is_map(body) ->
        acc = acc ++ (body["models"] || [])

        case body["nextPageToken"] do
          next when is_binary(next) and next != "" -> fetch_models(key, next, acc, left - 1)
          _ -> {:ok, acc}
        end

      {:ok, %{status: status}} ->
        Logger.warning("gemini models http #{status}")
        {:error, {:http, status}}

      {:error, _} ->
        Logger.warning("gemini models transport error")
        {:error, :transport}
    end
  end

  defp listed?(models, wanted) do
    case model_id(wanted) do
      {:ok, id} ->
        Enum.any?(models, fn model ->
          methods = model["supportedGenerationMethods"] || []
          name = model["name"] || ""
          generatable?(methods) and name_matches?(name, id)
        end)

      :error ->
        false
    end
  end

  defp generatable?(methods) do
    "generateContent" in methods or "streamGenerateContent" in methods
  end

  defp name_matches?(name, id) do
    name == id or name == "models/" <> id
  end

  defp model_id(model) when is_binary(model) do
    id = model |> String.trim() |> String.trim_leading("models/")

    if id != "" and id =~ ~r/^[A-Za-z0-9._-]+$/ do
      {:ok, id}
    else
      :error
    end
  end

  defp model_id(_), do: :error

  defp common_opts(key) do
    [headers: [{"x-goog-api-key", key}], retry: false, redirect: false]
    |> Keyword.merge(Application.get_env(:assistant_inference, :req_options, []))
  end

  defp stream_url(model) do
    base() <> "/v1beta/models/" <> model <> ":streamGenerateContent?alt=sse"
  end

  defp models_url, do: base() <> "/v1beta/models"

  defp base, do: String.trim_trailing(config().base_url, "/")

  defp fetch_key do
    cond do
      key = file_key() -> {:ok, key}
      key = env_key() -> {:ok, key}
      true -> :error
    end
  end

  defp file_key do
    case File.read(key_path()) do
      {:ok, text} -> blank_to_nil(text)
      _ -> nil
    end
  end

  defp env_key do
    case System.get_env("GEMINI_API_KEY") do
      nil -> nil
      text -> blank_to_nil(text)
    end
  end

  defp blank_to_nil(text) do
    text = String.trim(text)
    if text == "", do: nil, else: text
  end

  defp key_path, do: Map.fetch!(config(), :key_path)

  defp config, do: Application.fetch_env!(:assistant_inference, :gemini)
end
