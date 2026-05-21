defmodule StemiWeb.Admin.UsersLive do
  use StemiWeb, :live_view

  alias Stemi.Accounts
  alias Stemi.Accounts.User
  alias Stemi.Hospitals

  @impl true
  def mount(_params, _session, socket) do
    users = Accounts.list_users()
    hospitals = Hospitals.list_hospitals_for_select()

    socket =
      socket
      |> assign(:page_title, "Users")
      |> assign(:active_tab, :users)
      |> assign(:users, users)
      |> assign(:hospitals, hospitals)
      |> assign(:show_modal, false)
      |> assign(:editing_user, nil)
      |> assign(:changeset, nil)
      |> assign(:filter_role, "all")

    {:ok, socket}
  end

  @impl true
  def handle_event("new_user", _params, socket) do
    changeset = Accounts.change_user(%User{}, %{})

    socket =
      socket
      |> assign(:show_modal, true)
      |> assign(:editing_user, nil)
      |> assign(:changeset, changeset)

    {:noreply, socket}
  end

  @impl true
  def handle_event("edit_user", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)
    changeset = Accounts.change_user(user, %{})

    socket =
      socket
      |> assign(:show_modal, true)
      |> assign(:editing_user, user)
      |> assign(:changeset, changeset)

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply, assign(socket, show_modal: false, editing_user: nil, changeset: nil)}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      if socket.assigns.editing_user do
        socket.assigns.editing_user
        |> User.update_changeset(user_params)
        |> Map.put(:action, :validate)
      else
        %User{}
        |> User.changeset(user_params)
        |> Map.put(:action, :validate)
      end

    {:noreply, assign(socket, changeset: changeset)}
  end

  @impl true
  def handle_event("save_user", %{"user" => user_params}, socket) do
    result =
      if socket.assigns.editing_user do
        Accounts.update_user(socket.assigns.editing_user, user_params)
      else
        Accounts.create_user(user_params)
      end

    case result do
      {:ok, _user} ->
        action = if socket.assigns.editing_user, do: "updated", else: "created"

        socket =
          socket
          |> put_flash(:info, "User #{action} successfully!")
          |> assign(:users, Accounts.list_users())
          |> assign(:show_modal, false)
          |> assign(:editing_user, nil)
          |> assign(:changeset, nil)

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  @impl true
  def handle_event("delete_user", %{"id" => id}, socket) do
    user = Accounts.get_user!(id)

    case Accounts.delete_user(user) do
      {:ok, _} ->
        socket =
          socket
          |> put_flash(:info, "User deleted.")
          |> assign(:users, Accounts.list_users())

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete user.")}
    end
  end

  @impl true
  def handle_event("filter_role", %{"role" => role}, socket) do
    {:noreply, assign(socket, :filter_role, role)}
  end

  # --- Helpers ---

  defp filtered_users(users, "all"), do: users
  defp filtered_users(users, role), do: Enum.filter(users, &(&1.role == role))

  defp avatar_color("admin"), do: "#8b5c2a"
  defp avatar_color("phc"), do: "#22c55e"
  defp avatar_color("er_consultant"), do: "#a855f7"
  defp avatar_color("cardiologist"), do: "#ef4444"
  defp avatar_color("eligibility"), do: "#f59e0b"
  defp avatar_color("ems"), do: "#3b82f6"
  defp avatar_color("cath_lab"), do: "#ec4899"
  defp avatar_color(_), do: "#6b7280"

  defp initials(nil), do: "?"
  defp initials(""), do: "?"

  defp initials(name) do
    name
    |> String.split(" ")
    |> Enum.take(2)
    |> Enum.map(&String.first/1)
    |> Enum.join()
    |> String.upcase()
  end

  defp role_label("phc"), do: "PHC"
  defp role_label("ems"), do: "EMS"
  defp role_label("er_consultant"), do: "ER Consultant"
  defp role_label("cath_lab"), do: "Cath Lab"
  defp role_label(role), do: String.capitalize(role)

  @impl true
  def render(assigns) do
    ~H"""
    <div class="section-header">
      <div>
        <h1 class="section-header__title">User Management</h1>
        <span class="section-header__count">{length(@users)} users</span>
      </div>
      <div class="section-header__actions" style="display: flex; gap: 8px;">
        <a href="/admin/cases" class="btn btn--ghost btn--sm">📋 Cases</a>
        <button class="btn btn--primary btn--sm" phx-click="new_user" id="btn-new-user">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
          Add User
        </button>
      </div>
    </div>

    <!-- Role Filter Tabs -->
    <div class="tabs" id="role-tabs">
      <button
        class={"tab #{if @filter_role == "all", do: "tab--active"}"}
        phx-click="filter_role"
        phx-value-role="all"
      >All</button>
      <button
        :for={role <- ~w(admin phc er_consultant cardiologist eligibility ems cath_lab)}
        class={"tab #{if @filter_role == role, do: "tab--active"}"}
        phx-click="filter_role"
        phx-value-role={role}
      >{role_label(role)}</button>
    </div>

    <!-- User List -->
    <div class="user-list" id="user-list">
      <div
        :for={user <- filtered_users(@users, @filter_role)}
        class="user-card"
        id={"user-#{user.id}"}
      >
        <div class="user-card__avatar" style={"background: #{avatar_color(user.role)}"}>
          {initials(user.full_name)}
        </div>
        <div class="user-card__info">
          <div class="user-card__name">{user.full_name}</div>
          <div class="user-card__meta">
            <span class={"badge badge--#{user.role}"}>{role_label(user.role)}</span>
            <span class={"badge #{if user.is_active, do: "badge--active", else: "badge--inactive"}"}>
              {if user.is_active, do: "Active", else: "Inactive"}
            </span>
          </div>
        </div>
        <div class="user-card__actions">
          <button class="btn btn--ghost btn--icon" phx-click="edit_user" phx-value-id={user.id} title="Edit">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/>
              <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/>
            </svg>
          </button>
          <button
            class="btn btn--ghost btn--icon"
            phx-click="delete_user"
            phx-value-id={user.id}
            data-confirm="Delete this user? This cannot be undone."
            title="Delete"
          >
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#ef4444" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <polyline points="3,6 5,6 21,6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/>
            </svg>
          </button>
        </div>
      </div>

      <div :if={filtered_users(@users, @filter_role) == []} class="empty-state">
        <div class="empty-state__icon">👤</div>
        <div class="empty-state__text">
          {if @filter_role == "all", do: "No users yet. Create your first user.", else: "No #{role_label(@filter_role)} users."}
        </div>
        <button :if={@filter_role == "all"} class="btn btn--primary" phx-click="new_user">
          Create First User
        </button>
      </div>
    </div>

    <!-- Sign Out -->
    <div style="margin-top: 24px;">
      <form action="/logout" method="post">
        <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
        <button type="submit" class="btn btn--ghost btn--full" id="btn-logout">Sign Out</button>
      </form>
    </div>

    <!-- Modal Panel (slide-up on mobile) -->
    <div :if={@show_modal} class="modal-overlay" id="user-modal">
      <div class="modal-panel" phx-click-away="close_modal">
        <div class="modal-panel__handle"></div>
        <h2 class="modal-panel__title">
          {if @editing_user, do: "Edit User", else: "New User"}
        </h2>

        <.form :let={f} for={@changeset} phx-change="validate" phx-submit="save_user" id="user-form">
          <div class="form-group">
            <label class="form-label" for="user_full_name">Full Name</label>
            <input
              class="form-input"
              type="text"
              name="user[full_name]"
              id="user_full_name"
              value={f[:full_name].value}
              placeholder="e.g. Dr. Mohammed Al-Rashidi"
              required
            />
            <div :for={msg <- f[:full_name].errors |> Enum.map(&elem(&1, 0))} class="form-error">{msg}</div>
          </div>

          <div class="form-group">
            <label class="form-label" for="user_username">Username</label>
            <input
              class="form-input"
              type="text"
              name="user[username]"
              id="user_username"
              value={f[:username].value}
              placeholder="e.g. m.rashidi"
              autocapitalize="off"
              required
            />
            <div :for={msg <- f[:username].errors |> Enum.map(&elem(&1, 0))} class="form-error">{msg}</div>
          </div>

          <div class="form-group">
            <label class="form-label" for="user_password">
              {if @editing_user, do: "New Password (leave blank to keep)", else: "Password"}
            </label>
            <input
              class="form-input"
              type="password"
              name="user[password]"
              id="user_password"
              placeholder={if @editing_user, do: "••••••••", else: "Min 6 characters"}
              required={!@editing_user}
            />
            <div :for={msg <- f[:password].errors |> Enum.map(&elem(&1, 0))} class="form-error">{msg}</div>
          </div>

          <div class="form-group">
            <label class="form-label" for="user_role">Role</label>
            <select class="form-select" name="user[role]" id="user_role" required>
              <option value="">Select role…</option>
              <option :for={role <- ~w(admin phc er_consultant cardiologist eligibility ems cath_lab)} value={role} selected={f[:role].value == role}>
                {role_label(role)}
              </option>
            </select>
            <div :for={msg <- f[:role].errors |> Enum.map(&elem(&1, 0))} class="form-error">{msg}</div>
          </div>

          <div class="form-group">
            <label class="form-label" for="user_hospital_id">Linked Facility</label>
            <select class="form-select" name="user[hospital_id]" id="user_hospital_id">
              <option value="">None (optional)</option>
              <option :for={{name, id} <- @hospitals} value={id} selected={f[:hospital_id].value == id}>
                {name}
              </option>
            </select>
          </div>

          <div class="form-group">
            <label class="form-label" for="user_location">Location (for PHC users)</label>
            <input
              class="form-input"
              type="text"
              name="user[location]"
              id="user_location"
              value={f[:location].value}
              placeholder="e.g. PHC Al-Malaz, Riyadh"
            />
          </div>

          <div class="form-group">
            <label class="form-checkbox">
              <input type="hidden" name="user[is_active]" value="false" />
              <input
                type="checkbox"
                name="user[is_active]"
                id="user_is_active"
                value="true"
                checked={f[:is_active].value != false}
              />
              <span>Active</span>
            </label>
          </div>

          <div class="flex gap-2 mt-4">
            <button type="button" class="btn btn--ghost" style="flex:1" phx-click="close_modal">Cancel</button>
            <button type="submit" class="btn btn--primary" style="flex:2" phx-disable-with="Saving…">
              {if @editing_user, do: "Update User", else: "Create User"}
            </button>
          </div>
        </.form>
      </div>
    </div>
    """
  end
end
