defmodule Assistant.Reply.Request do
  alias Cards
  alias Assistant.Journal

  def build(state) do
    case Journal.system_prompt() do
      {:ok, system} ->
        %{system: contract(system), contents: contents(state), tools: gemini_tools()}

      {:error, _} ->
        :system_prompt
    end
  end

  defp contents(%{manual: %{prompt: _prompt}, base_contents: base, tool_log: log} = state)
       when is_list(base) and log != [] do
    resume(base ++ log, state)
  end

  defp contents(%{manual: %{prompt: prompt}} = state) do
    resume([%{"role" => "user", "parts" => [%{"text" => prompt}]}], state)
  end

  defp contents(%{base_contents: base, tool_log: log} = state) when is_list(base) and log != [] do
    resume(base ++ log, state)
  end

  defp contents(state) do
    %{contents: contents} = Journal.outbound(state.chat_id, "", state.phase == :resume)
    contents
  end

  defp resume(contents, %{phase: :resume, base_text: text}) when is_binary(text) and text != "" do
    contents ++
      [
        %{"role" => "model", "parts" => [%{"text" => text}]},
        %{"role" => "user", "parts" => [%{"text" => "продолжай с места обрыва"}]}
      ]
  end

  defp resume(contents, _state), do: contents

  defp contract(system) do
    extra = Cards.instructions()
    system = if is_binary(system), do: String.trim(system), else: ""
    if system == "", do: extra, else: system <> "\n\n" <> extra
  end

  defp gemini_tools do
    Enum.map(Cards.tools(), fn tool ->
      %{
        "name" => tool["name"],
        "description" => tool["description"],
        "parameters" => Map.delete(tool["inputSchema"], "additionalProperties")
      }
    end)
  end
end
