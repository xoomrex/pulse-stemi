defmodule Stemi.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "users" do
    field :username, :string
    field :password_hash, :string
    field :password, :string, virtual: true
    field :full_name, :string
    field :role, :string
    field :is_active, :boolean, default: true
    field :hospital_id, :integer
    field :location, :string
    field :short_id, :string

    timestamps(type: :utc_datetime)
  end

  @roles ~w(admin phc er_consultant cardiologist eligibility ems cath_lab)

  def roles, do: @roles

  def display_id(%__MODULE__{short_id: sid}) when is_binary(sid), do: sid
  def display_id(_), do: "—"

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :password, :full_name, :role, :hospital_id, :is_active, :location])
    |> validate_required([:username, :password, :full_name, :role])
    |> validate_inclusion(:role, @roles)
    |> validate_length(:username, min: 3, max: 30)
    |> validate_length(:password, min: 6, max: 100)
    |> unique_constraint(:username)
    |> maybe_generate_short_id()
    |> hash_password()
  end

  def update_changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :full_name, :role, :hospital_id, :is_active, :location])
    |> validate_required([:username, :full_name, :role])
    |> validate_inclusion(:role, @roles)
    |> validate_length(:username, min: 3, max: 30)
    |> unique_constraint(:username)
    |> maybe_hash_password(attrs)
  end

  defp maybe_generate_short_id(changeset) do
    if get_field(changeset, :short_id) do
      changeset
    else
      random = :crypto.strong_rand_bytes(2) |> Base.encode16()
      put_change(changeset, :short_id, "U-#{random}")
    end
  end

  defp maybe_hash_password(changeset, attrs) do
    password = attrs["password"] || attrs[:password]

    if password && password != "" do
      changeset
      |> put_change(:password, password)
      |> validate_length(:password, min: 6, max: 100)
      |> hash_password()
    else
      changeset
    end
  end

  defp hash_password(%{valid?: true, changes: %{password: password}} = changeset) do
    put_change(changeset, :password_hash, Pbkdf2.hash_pwd_salt(password))
  end

  defp hash_password(changeset), do: changeset
end
