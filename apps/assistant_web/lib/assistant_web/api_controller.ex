defmodule AssistantWeb.ApiController do
  use Phoenix.Controller, formats: [:json]

  def health(conn, _params) do
    json(conn, %{ok: true})
  end

  def chat(conn, %{"prompt" => prompt}) when is_binary(prompt) do
    case Assistant.complete(prompt) do
      {:ok, reply} ->
        json(conn, %{reply: reply})

      {:error, :empty} ->
        error(conn, 400, "empty")

      {:error, :busy} ->
        error(conn, 409, "busy")

      {:error, reason} ->
        error(conn, status_for(reason), error_text(reason))
    end
  end

  def chat(conn, _params) do
    error(conn, 400, "expected JSON object with a prompt string")
  end

  defp error(conn, status, message) do
    conn
    |> put_status(status)
    |> json(%{error: message})
  end

  defp status_for(:unavailable), do: 503
  defp status_for(:system_prompt), do: 500
  defp status_for(_reason), do: 502

  defp error_text(:unavailable), do: "unavailable"
  defp error_text(:system_prompt), do: "system prompt unreadable"
  defp error_text(:empty_response), do: "empty model response"
  defp error_text(:timeout), do: "timeout"
  defp error_text(:cancelled), do: "cancelled"
  defp error_text(:transport), do: "inference unreachable"
  defp error_text(:invalid_response), do: "invalid model response"
  defp error_text(:api_error), do: "model error"
  defp error_text(:crash), do: "inference failed"
  defp error_text({:http, status}) when is_integer(status), do: "inference HTTP #{status}"
  defp error_text(_reason), do: "inference failed"
end
