defmodule Stemi.Repo.Migrations.CreateCaseComments do
  use Ecto.Migration

  def change do
    # Drop the flat :comments column if a previous version of this branch added it.
    execute "ALTER TABLE cases DROP COLUMN IF EXISTS comments", ""

    create table(:case_comments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :case_id, references(:cases, type: :binary_id, on_delete: :delete_all), null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :nilify_all)
      add :parent_id, references(:case_comments, type: :binary_id, on_delete: :delete_all)
      add :body, :text, null: false
      add :is_deleted, :boolean, default: false, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:case_comments, [:case_id])
    create index(:case_comments, [:parent_id])
    create index(:case_comments, [:case_id, :inserted_at])
  end
end
