defmodule Stemi.Repo.Migrations.AddLocationToUsersAndErFieldsToCases do
  use Ecto.Migration

  def change do
    # Add missing location column to users
    alter table(:users) do
      add_if_not_exists :location, :text
    end

    # Add ER consultant fields to cases
    alter table(:cases) do
      add_if_not_exists :er_consultant_id, references(:users, type: :binary_id, on_delete: :nothing)
      add_if_not_exists :er_decision, :text
      add_if_not_exists :er_decided_at, :utc_datetime
    end

    # Make phc_hospital_id and ecg_photo_url nullable
    execute "ALTER TABLE cases ALTER COLUMN phc_hospital_id DROP NOT NULL", ""
    execute "ALTER TABLE cases ALTER COLUMN ecg_photo_url DROP NOT NULL", ""
  end
end
