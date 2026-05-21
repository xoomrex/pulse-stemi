defmodule Stemi.Repo.Migrations.CreateCases do
  use Ecto.Migration

  def change do
    create table(:cases, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :patient_id, :text, null: false
      add :ecg_photo_url, :text, null: false
      add :status, :text, null: false, default: "pending_review"

      # PHC info
      add :phc_user_id, references(:users, type: :binary_id, on_delete: :nothing), null: false
      add :phc_hospital_id, references(:hospitals, on_delete: :nothing), null: false

      # Cardiology review
      add :cardiologist_id, references(:users, type: :binary_id, on_delete: :nothing)
      add :cardiology_decision, :text
      add :cardiology_decided_at, :utc_datetime

      # Eligibility review
      add :eligibility_id, references(:users, type: :binary_id, on_delete: :nothing)
      add :mrn_number, :text
      add :eligibility_decided_at, :utc_datetime

      # EMS dispatch
      add :ems_user_id, references(:users, type: :binary_id, on_delete: :nothing)
      add :ems_dispatched_at, :utc_datetime

      # Soft delete
      add :is_deleted, :boolean, default: false, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:cases, [:status])
    create index(:cases, [:phc_user_id])
    create index(:cases, [:phc_hospital_id])
    create index(:cases, [:is_deleted])
    create index(:cases, [:inserted_at])
  end
end
