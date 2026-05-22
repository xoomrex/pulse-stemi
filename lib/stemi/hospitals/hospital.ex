defmodule Stemi.Hospitals.Hospital do
  use Ecto.Schema

  schema "hospitals" do
    field :name, :string
    field :type, :string
    field :cluster, :string
    field :map_url, :string
    field :lat, :float
    field :lng, :float

    timestamps(type: :utc_datetime)
  end
end
