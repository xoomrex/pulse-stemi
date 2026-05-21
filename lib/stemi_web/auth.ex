defmodule StemiWeb.Auth do
  @moduledoc """
  Authentication plug — reads user_id from session, loads user, assigns to conn/socket.
  """
  import Plug.Conn
  alias Stemi.Accounts

  def init(opts), do: opts

  def call(conn, _opts) do
    user_id = get_session(conn, :user_id)

    if user_id do
      try do
        user = Accounts.get_user!(user_id)
        assign(conn, :current_user, user)
      rescue
        Ecto.NoResultsError ->
          conn
          |> delete_session(:user_id)
          |> assign(:current_user, nil)
      end
    else
      assign(conn, :current_user, nil)
    end
  end

  @doc "Plug that requires an authenticated user — redirects to /login if not."
  def require_auth(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn
      |> Phoenix.Controller.put_flash(:error, "Please log in to continue.")
      |> Phoenix.Controller.redirect(to: "/login")
      |> halt()
    end
  end

  @doc "Plug that requires a specific role."
  def require_role(conn, roles) when is_list(roles) do
    user = conn.assigns[:current_user]

    if user && user.role in roles do
      conn
    else
      conn
      |> Phoenix.Controller.put_flash(:error, "Access denied.")
      |> Phoenix.Controller.redirect(to: "/dashboard")
      |> halt()
    end
  end

  @doc "Assigns current_user to LiveView socket from session, gating non-admin desktop users to /install."
  def on_mount(:default, _params, session, socket) do
    case session["user_id"] do
      nil ->
        {:halt, Phoenix.LiveView.redirect(socket, to: "/login")}

      user_id ->
        try do
          user = Accounts.get_user!(user_id)
          device = session["device_type"] || "desktop"

          {:cont,
           socket
           |> Phoenix.Component.assign(:current_user, user)
           |> Phoenix.Component.assign(:device_type, device)}
        rescue
          Ecto.NoResultsError ->
            {:halt, Phoenix.LiveView.redirect(socket, to: "/login")}
        end
    end
  end

  def on_mount(:admin_only, _params, session, socket) do
    case session["user_id"] do
      nil ->
        {:halt, Phoenix.LiveView.redirect(socket, to: "/login")}

      user_id ->
        try do
          user = Accounts.get_user!(user_id)

          if user.role == "admin" do
            {:cont,
             socket
             |> Phoenix.Component.assign(:current_user, user)
             |> Phoenix.Component.assign(:device_type, session["device_type"] || "desktop")}
          else
            {:halt,
             socket
             |> Phoenix.LiveView.put_flash(:error, "Admin access required.")
             |> Phoenix.LiveView.redirect(to: "/dashboard")}
          end
        rescue
          Ecto.NoResultsError ->
            {:halt, Phoenix.LiveView.redirect(socket, to: "/login")}
        end
    end
  end

  # on_mount for `/simulate/:sim_user_id/...` LiveViews. Validates that the
  # cookie-bound user is an admin, then loads the impersonated user from the
  # URL param. Each iframe gets its own param so they don't collide via shared
  # cookies. Bypasses the desktop gate so admins can run a simulator on a laptop.
  def on_mount(:simulated, params, session, socket) do
    real_admin_id = session["user_id"]
    simulated_id = params["sim_user_id"]

    with admin_id when is_binary(admin_id) <- real_admin_id,
         simulated_id when is_binary(simulated_id) <- simulated_id,
         %{role: "admin"} = admin <- safe_get_user(admin_id),
         simulated when not is_nil(simulated) <- safe_get_user(simulated_id) do
      {:cont,
       socket
       |> Phoenix.Component.assign(:current_user, simulated)
       |> Phoenix.Component.assign(:real_admin, admin)
       |> Phoenix.Component.assign(:device_type, "mobile")
       |> Phoenix.Component.assign(:is_simulated, true)}
    else
      _ ->
        {:halt, Phoenix.LiveView.redirect(socket, to: "/login")}
    end
  end

  defp safe_get_user(id) do
    try do
      Accounts.get_user!(id)
    rescue
      Ecto.NoResultsError -> nil
    end
  end
end
