defmodule Stemi.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :username, :text, null: false
      add :password_hash, :text, null: false
      add :full_name, :text, null: false
      add :role, :text, null: false
      add :hospital_id, references(:hospitals, on_delete: :nothing)
      add :is_active, :boolean, default: true, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:username])
    create index(:users, [:role])
    create index(:users, [:hospital_id])
  end
end
