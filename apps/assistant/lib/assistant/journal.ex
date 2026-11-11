defmodule Assistant.Journal do
  import Ecto.Query

  alias __MODULE__.{Chat, Message, Provider}
  alias Assistant.Repo
  alias Assistant.Reply.Text

  def ensure_provider!(name) when is_binary(name) do
    case provider_row() do
      nil -> Repo.insert!(%Provider{name: name})
      row -> row
    end
  end

  def provider_name do
    case provider_row() do
      nil -> nil
      row -> row.name
    end
  end

  def select_provider(name) when is_atom(name), do: select_provider(Atom.to_string(name))

  def select_provider(name) when is_binary(name) do
    name = String.trim(name)

    if name == "" do
      {:error, :empty}
    else
      result =
        case provider_row() do
          nil -> Repo.insert(%Provider{name: name})
          row -> row |> Ecto.Changeset.change(name: name) |> Repo.update()
        end

      case result do
        {:ok, _} -> :ok
        {:error, reason} -> {:error, reason}
      end
    end
  end

  def list_chats(context \\ :all)

  def list_chats(:all) do
    Repo.all(from(c in Chat, order_by: [desc: c.updated_at, desc: c.id]))
  end

  def list_chats(context) when is_binary(context) do
    Repo.all(
      from(c in Chat,
        where: c.context == ^context,
        order_by: [desc: c.updated_at, desc: c.id]
      )
    )
  end

  def messages(chat_id) do
    Repo.all(from(m in Message, where: m.chat_id == ^chat_id, order_by: [asc: m.seq]))
  end

  def chat?(id), do: Repo.exists?(from(c in Chat, where: c.id == ^id))

  def get_message(id), do: Repo.get(Message, id)

  def spend(chat_id) do
    case Repo.get(Chat, chat_id) do
      nil -> 0
      chat -> chat.token_spend
    end
  end

  def context_used(chat_id) do
    Repo.one(
      from(m in Message,
        where: m.chat_id == ^chat_id and m.role == "assistant",
        order_by: [desc: m.seq],
        limit: 1,
        select: m.prompt_tokens
      )
    ) || 0
  end

  def spend_total do
    Repo.one(from(c in Chat, select: sum(c.token_spend))) || 0
  end

  def create_chat(context \\ "misc") when is_binary(context) do
    Repo.insert(%Chat{context: context})
  end

  def system_prompt do
    path = Application.fetch_env!(:assistant, :system_prompt_path)

    case File.read(path) do
      {:ok, text} -> {:ok, String.trim(text)}
      {:error, _} -> {:error, :system_prompt}
    end
  end

  def start_turn(chat_id, text) do
    text = String.trim(text)

    Repo.transaction(fn ->
      chat = Repo.get!(Chat, chat_id)
      seq = next_seq(chat_id)

      user =
        Repo.insert!(%Message{
          chat_id: chat_id,
          seq: seq,
          role: "user",
          content: text,
          status: "complete"
        })

      assistant =
        Repo.insert!(%Message{
          chat_id: chat_id,
          seq: seq + 1,
          role: "assistant",
          status: "partial"
        })

      title = if chat.title == "Новый чат", do: Text.clip_title(text), else: chat.title

      chat
      |> Ecto.Changeset.change(title: title, updated_at: now())
      |> Repo.update!()

      %{turn_id: assistant.id, user: user, assistant: assistant}
    end)
  end

  def outbound(chat_id, system, resume?) do
    contents =
      chat_id
      |> messages()
      |> Enum.filter(&(&1.content != ""))
      |> Enum.map(fn
        %{role: "assistant", content: content} ->
          %{"role" => "model", "parts" => [%{"text" => content}]}

        %{role: "user", content: content} ->
          %{"role" => "user", "parts" => [%{"text" => content}]}
      end)

    contents =
      if resume? and match?(%{"role" => "model"}, List.last(contents)) do
        contents ++ [%{"role" => "user", "parts" => [%{"text" => "продолжай с места обрыва"}]}]
      else
        contents
      end

    %{system: system, contents: contents}
  end

  def write_partial(id, content, thinking) do
    from(m in Message, where: m.id == ^id and m.status == "partial")
    |> Repo.update_all(set: [content: content, thinking: thinking, updated_at: now()])
  end

  def finish(id, status, content, thinking) when status in ["complete", "interrupted"] do
    from(m in Message, where: m.id == ^id and m.status == "partial")
    |> Repo.update_all(
      set: [status: status, content: content, thinking: thinking, updated_at: now()]
    )
  end

  def add_usage(id, prompt, eval) when prompt >= 0 and eval >= 0 do
    from(m in Message, where: m.id == ^id)
    |> Repo.update_all(inc: [prompt_tokens: prompt, eval_tokens: eval], set: [updated_at: now()])

    case Repo.get(Message, id) do
      nil -> :ok
      message -> {:ok, message.chat_id, recompute_spend(message.chat_id)}
    end
  end

  def interrupt_open_partials(chat_id \\ nil)

  def interrupt_open_partials(nil) do
    from(m in Message, where: m.status == "partial")
    |> Repo.update_all(set: [status: "interrupted", updated_at: now()])
  end

  def interrupt_open_partials(chat_id) when is_integer(chat_id) do
    from(m in Message, where: m.status == "partial" and m.chat_id == ^chat_id)
    |> Repo.update_all(set: [status: "interrupted", updated_at: now()])
  end

  def recompute_spend(chat_id) do
    spent =
      Repo.one(
        from(m in Message,
          where: m.chat_id == ^chat_id and m.role == "assistant",
          select: coalesce(sum(m.prompt_tokens), 0) + coalesce(sum(m.eval_tokens), 0)
        )
      ) || 0

    from(c in Chat, where: c.id == ^chat_id)
    |> Repo.update_all(set: [token_spend: spent, updated_at: now()])

    spent
  end

  defp provider_row, do: Repo.one(from(p in Provider, limit: 1))

  defp next_seq(chat_id) do
    last = Repo.one(from(m in Message, where: m.chat_id == ^chat_id, select: max(m.seq)))
    (last || 0) + 1
  end

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
