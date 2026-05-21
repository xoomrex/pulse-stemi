defmodule Stemi.Repo.Migrations.MakePatientIdOptional do
  use Ecto.Migration

  def change do
    execute "ALTER TABLE cases ALTER COLUMN patient_id DROP NOT NULL",
            "ALTER TABLE cases ALTER COLUMN patient_id SET NOT NULL"
  end
end
