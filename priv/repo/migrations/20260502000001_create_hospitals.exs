defmodule Stemi.Repo.Migrations.CreateHospitals do
  use Ecto.Migration

  def change do
    create table(:hospitals) do
      add :name, :text, null: false
      add :type, :text
      add :cluster, :text
      add :coordinates, :point

      timestamps(type: :utc_datetime)
    end

    create index(:hospitals, [:type])
    create index(:hospitals, [:cluster])
  end
end
