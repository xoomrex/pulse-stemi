defmodule StemiWeb.SessionController do
  use StemiWeb, :controller

  alias Stemi.Accounts

  def create(conn, %{"session" => %{"username" => username, "password" => password}}) do
    ip = conn.remote_ip |> :inet.ntoa() |> to_string()

    case Accounts.authenticate(username, password) do
      {:ok, user} ->
        Accounts.log_activity(user.id, "login", ip: ip)

        conn
        |> put_session(:user_id, user.id)
        |> configure_session(renew: true)
        |> put_flash(:info, "Welcome, #{user.full_name}!")
        |> redirect(to: home_path(user.role))

      {:error, :account_disabled} ->
        conn
        |> put_flash(:error, "Your account has been disabled.")
        |> redirect(to: "/login")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Invalid username or password.")
        |> redirect(to: "/login")
    end
  end

  def delete(conn, _params) do
    user_id = get_session(conn, :user_id)
    if user_id, do: Accounts.log_activity(user_id, "logout")

    conn
    |> clear_session()
    |> put_flash(:info, "Logged out successfully.")
    |> redirect(to: "/login")
  end

  # Each role goes to their own page
  defp home_path("admin"), do: "/admin/users"
  defp home_path("phc"), do: "/phc/cases"
  defp home_path("er_consultant"), do: "/er/review"
  defp home_path("cardiologist"), do: "/cardio/review"
  defp home_path("eligibility"), do: "/elig/cases"
  defp home_path("ems"), do: "/ems/dispatch"
  defp home_path("cath_lab"), do: "/cath-lab/prepare"
  defp home_path(_), do: "/dashboard"
end
