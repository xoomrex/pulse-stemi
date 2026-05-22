defmodule Stemi.Repo.Migrations.AddLatLngToHospitals do
  use Ecto.Migration

  def change do
    alter table(:hospitals) do
      add_if_not_exists :lat, :float
      add_if_not_exists :lng, :float
    end
  end
end
