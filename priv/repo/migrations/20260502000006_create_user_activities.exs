defmodule Stemi.Repo.Migrations.CreateUserActivities do
  use Ecto.Migration

  def change do
    create table(:user_activities) do
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :action, :string, null: false
      add :details, :map, default: %{}
      add :ip_address, :string

      timestamps(updated_at: false, type: :utc_datetime)
    end

    create index(:user_activities, [:user_id])
    create index(:user_activities, [:action])
    create index(:user_activities, [:inserted_at])
  end
end
