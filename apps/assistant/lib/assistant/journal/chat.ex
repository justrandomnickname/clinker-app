defmodule Assistant.Journal.Chat do
  use Ecto.Schema

  schema "chats" do
    field(:title, :string, default: "Новый чат")
    field(:context, :string)
    field(:token_spend, :integer, default: 0)
    has_many(:messages, Assistant.Journal.Message)
    timestamps(type: :utc_datetime)
  end
end
