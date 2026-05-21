defmodule Stemi.Repo.Migrations.CreateCaseEvents do
  use Ecto.Migration

  def change do
    create table(:case_events, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :case_id, references(:cases, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :nothing), null: false
      add :event_type, :text, null: false
      add :metadata, :map, default: %{}

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:case_events, [:case_id])
    create index(:case_events, [:user_id])
    create index(:case_events, [:event_type])
  end
end
