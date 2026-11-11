defmodule Assistant.Journal.Provider do
  use Ecto.Schema

  schema "provider" do
    field :name, :string
    timestamps(type: :utc_datetime)
  end
end
