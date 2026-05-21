defmodule Stemi.Repo.Migrations.AddCathLabAndShortIds do
  use Ecto.Migration

  def change do
    alter table(:cases) do
      add :case_number, :serial
      add :cath_lab_user_id, references(:users, type: :binary_id)
      add :cath_lab_confirmed_at, :utc_datetime
      add :cath_lab_status, :string, default: "pending"
    end

    alter table(:users) do
      add :short_id, :string, size: 10
    end

    create unique_index(:users, [:short_id])
  end
end
