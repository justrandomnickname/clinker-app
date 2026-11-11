defmodule Assistant.Reply.Request do
  alias Assistant.Journal

  def build(%{manual: %{prompt: prompt}, phase: phase, base_text: base_text}) do
    case Journal.system_prompt() do
      {:ok, system} ->
        contents = [%{"role" => "user", "parts" => [%{"text" => prompt}]}]

        contents =
          if phase == :resume and base_text != "" do
            contents ++
              [
                %{"role" => "model", "parts" => [%{"text" => base_text}]},
                %{"role" => "user", "parts" => [%{"text" => "продолжай с места обрыва"}]}
              ]
          else
            contents
          end

        %{system: system, contents: contents}

      {:error, _} ->
        :system_prompt
    end
  end

  def build(state) do
    case Journal.system_prompt() do
      {:ok, system} -> Journal.outbound(state.chat_id, system, state.phase == :resume)
      {:error, _} -> :system_prompt
    end
  end
end
