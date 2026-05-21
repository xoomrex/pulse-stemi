defmodule Stemi.Repo.Migrations.AddMapUrlToHospitals do
  use Ecto.Migration

  def change do
    alter table(:hospitals) do
      add_if_not_exists :map_url, :text
    end
  end
end
