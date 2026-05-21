defmodule Stemi.Accounts.UserActivity do
  use Ecto.Schema

  @primary_key {:id, :id, autogenerate: true}

  schema "user_activities" do
    field :action, :string
    field :details, :map, default: %{}
    field :ip_address, :string

    belongs_to :user, Stemi.Accounts.User, type: :binary_id

    timestamps(updated_at: false, type: :utc_datetime)
  end
end
