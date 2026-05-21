defmodule Stemi.Accounts do
  @moduledoc """
  The Accounts context — user CRUD and authentication.
  """
  import Ecto.Query
  alias Stemi.Repo
  alias Stemi.Accounts.User

  ## User CRUD

  def list_users do
    User
    |> order_by([u], [asc: u.role, asc: u.full_name])
    |> Repo.all()
  end

  def get_user!(id), do: Repo.get!(User, id)

  def create_user(attrs) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  def update_user(%User{} = user, attrs) do
    user
    |> User.update_changeset(attrs)
    |> Repo.update()
  end

  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  def change_user(%User{} = user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end

  ## Authentication

  def authenticate(username, password) do
    user = Repo.get_by(User, username: username)

    cond do
      user && user.is_active && Pbkdf2.verify_pass(password, user.password_hash) ->
        {:ok, user}

      user && !user.is_active ->
        {:error, :account_disabled}

      true ->
        Pbkdf2.no_user_verify()
        {:error, :invalid_credentials}
    end
  end
  ## Activity Logging

  alias Stemi.Accounts.UserActivity

  def log_activity(user_id, action, opts \\ []) do
    %UserActivity{
      user_id: user_id,
      action: action,
      details: Keyword.get(opts, :details, %{}),
      ip_address: Keyword.get(opts, :ip, nil)
    }
    |> Repo.insert()
  end

  def list_activities(opts \\ []) do
    limit = Keyword.get(opts, :limit, 50)

    UserActivity
    |> order_by([a], desc: a.inserted_at)
    |> limit(^limit)
    |> preload(:user)
    |> Repo.all()
  end
end
