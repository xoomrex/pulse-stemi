defmodule Stemi.Hospitals do
  @moduledoc """
  The Hospitals context — facility queries.
  """
  import Ecto.Query
  alias Stemi.Repo
  alias Stemi.Hospitals.Hospital

  def list_hospitals do
    Hospital
    |> order_by([h], asc: h.name)
    |> Repo.all()
  end

  def list_hospitals_for_select do
    Hospital
    |> order_by([h], asc: h.name)
    |> select([h], {h.name, h.id})
    |> Repo.all()
  end

  def get_hospital!(id), do: Repo.get!(Hospital, id)
end
