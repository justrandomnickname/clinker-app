defmodule Assistant.Journal.Message do
  use Ecto.Schema

  schema "messages" do
    belongs_to :chat, Assistant.Journal.Chat
    field :seq, :integer
    field :role, :string
    field :content, :string, default: ""
    field :thinking, :string, default: ""
    field :status, :string
    field :prompt_tokens, :integer, default: 0
    field :eval_tokens, :integer, default: 0
    timestamps(type: :utc_datetime)
  end
end
