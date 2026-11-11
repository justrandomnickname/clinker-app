defmodule Assistant.Repo.Migrations.CreateJournal do
  use Ecto.Migration

  def change do
    create table(:chats) do
      add :title, :string, null: false, default: "Новый чат"
      add :token_spend, :integer, null: false, default: 0
      timestamps(type: :utc_datetime)
    end

    create table(:messages) do
      add :chat_id, references(:chats, on_delete: :delete_all), null: false
      add :seq, :integer, null: false
      add :role, :string, null: false
      add :content, :text, null: false, default: ""
      add :thinking, :text, null: false, default: ""
      add :status, :string, null: false
      add :prompt_tokens, :integer, null: false, default: 0
      add :eval_tokens, :integer, null: false, default: 0
      timestamps(type: :utc_datetime)
    end

    create unique_index(:messages, [:chat_id, :seq])

    create table(:provider) do
      add :name, :string, null: false
      timestamps(type: :utc_datetime)
    end
  end
end
