defmodule StemiWeb.PageController do
  use StemiWeb, :controller

  def home(conn, _params) do
    case conn.assigns[:current_user] do
      nil -> redirect(conn, to: "/login")
      %{role: "admin"} -> redirect(conn, to: "/admin/users")
      %{role: "phc"} -> redirect(conn, to: "/phc/cases")
      _ -> redirect(conn, to: "/dashboard")
    end
  end
end
