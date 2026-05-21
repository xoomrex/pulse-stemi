defmodule Stemi.Repo.Migrations.AddIdPhotoToCases do
  use Ecto.Migration

  def change do
    alter table(:cases) do
      add :id_photo_url, :text
    end
  end
end
