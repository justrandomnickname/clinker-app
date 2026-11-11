defmodule Assistant.Repo.Migrations.AddChatContext do
  use Ecto.Migration

  def change do
    alter table(:chats) do
      add(:context, :string, null: false, default: "test")
    end

    create(index(:chats, [:context]))
  end
end
