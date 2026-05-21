defmodule StemiWeb.Admin.SimulatorLive do
  @moduledoc """
  Demo simulator — renders multiple "phones" side by side, each one a real,
  authenticated session for a different user. Each phone is an iframe pointing
  at `/simulate/:sim_user_id`. Authentication is enforced server-side: only
  admins can mount the impersonated routes, and `current_user` for the iframe
  is loaded from the URL param, not the cookie.
  """
  use StemiWeb, :live_view

  alias Stemi.Accounts

  @impl true
  def mount(_params, _session, socket) do
    users = list_active_non_admin_users()

    # Default: pick one user per role (in canonical order), capped at 6.
    default_picks =
      ["phc", "er_consultant", "cardiologist", "eligibility", "ems", "cath_lab"]
      |> Enum.map(fn role -> Enum.find(users, &(&1.role == role)) end)
      |> Enum.reject(&is_nil/1)
      |> Enum.map(& &1.id)
      |> Enum.take(6)

    {:ok,
     socket
     |> assign(:page_title, "Demo Simulator")
     |> assign(:active_tab, :simulator)
     |> assign(:users, users)
     |> assign(:picked_ids, default_picks)
     |> assign(:columns, columns_for(length(default_picks)))}
  end

  @impl true
  def handle_event("toggle_user", %{"id" => id}, socket) do
    picked =
      if id in socket.assigns.picked_ids do
        List.delete(socket.assigns.picked_ids, id)
      else
        socket.assigns.picked_ids ++ [id]
      end
      |> Enum.take(10)

    {:noreply,
     socket
     |> assign(:picked_ids, picked)
     |> assign(:columns, columns_for(length(picked)))}
  end

  @impl true
  def handle_event("clear", _params, socket) do
    {:noreply, assign(socket, picked_ids: [], columns: 1)}
  end

  defp list_active_non_admin_users do
    Accounts.list_users()
    |> Enum.filter(fn u -> u.is_active && u.role != "admin" end)
  end

  defp columns_for(n) when n <= 1, do: 1
  defp columns_for(n) when n <= 2, do: 2
  defp columns_for(n) when n <= 4, do: 2
  defp columns_for(n) when n <= 6, do: 3
  defp columns_for(_), do: 4

  defp picked_users(users, ids) do
    by_id = Map.new(users, &{&1.id, &1})
    Enum.map(ids, &Map.get(by_id, &1)) |> Enum.reject(&is_nil/1)
  end

  defp role_color("phc"), do: "#3b82f6"
  defp role_color("er_consultant"), do: "#a855f7"
  defp role_color("cardiologist"), do: "#22c55e"
  defp role_color("eligibility"), do: "#f59e0b"
  defp role_color("ems"), do: "#ef4444"
  defp role_color("cath_lab"), do: "#ec4899"
  defp role_color(_), do: "#6b7280"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="section-header">
      <div>
        <h1 class="section-header__title">Demo Simulator</h1>
        <span class="section-header__count">{length(@picked_ids)} of {length(@users)} users · real DB · live PubSub</span>
      </div>
      <button class="btn btn--ghost btn--sm" phx-click="clear">Clear</button>
    </div>

    <details class="sim-picker">
      <summary class="sim-picker__summary">Pick which users to simulate ({length(@picked_ids)} selected, max 10)</summary>
      <div class="sim-picker__grid">
        <%= for u <- @users do %>
          <button
            type="button"
            class={"sim-picker__chip #{if u.id in @picked_ids, do: "is-on"}"}
            style={"--chip-color: #{role_color(u.role)}"}
            phx-click="toggle_user"
            phx-value-id={u.id}
          >
            <span class="sim-picker__chip-dot"></span>
            <span class="sim-picker__chip-role">{u.role}</span>
            <span class="sim-picker__chip-name">{u.full_name}</span>
          </button>
        <% end %>
      </div>
    </details>

    <div :if={@picked_ids == []} class="sim-empty">
      <div class="sim-empty__icon">📱</div>
      <div class="sim-empty__text">Pick at least one user above to start the simulator.</div>
    </div>

    <div
      :if={@picked_ids != []}
      class="sim-grid"
      style={"--sim-cols: #{@columns}"}
    >
      <%= for user <- picked_users(@users, @picked_ids) do %>
        <div class="phone-frame" data-role={user.role}>
          <div class="phone-frame__notch"></div>
          <div class="phone-frame__label" style={"background: #{role_color(user.role)}"}>
            {user.full_name} · {user.role}
          </div>
          <div class="phone-frame__screen">
            <iframe
              src={"/simulate/#{user.id}"}
              title={"Pulse — #{user.full_name}"}
              loading="lazy"
              allow="geolocation; clipboard-read; clipboard-write"
            />
          </div>
        </div>
      <% end %>
    </div>

    <style>
      .sim-picker {
        background: var(--bg-card);
        border: 1px solid var(--border);
        border-radius: var(--radius);
        padding: 12px 16px;
        margin: 12px 0 16px;
      }
      .sim-picker__summary {
        font-weight: 600;
        cursor: pointer;
        color: var(--text-primary);
        font-size: 14px;
      }
      .sim-picker__grid {
        display: flex;
        flex-wrap: wrap;
        gap: 8px;
        margin-top: 12px;
      }
      .sim-picker__chip {
        background: var(--bg-input);
        border: 1px solid var(--border);
        border-radius: 999px;
        padding: 6px 12px;
        font-size: 12px;
        color: var(--text-secondary);
        cursor: pointer;
        display: inline-flex;
        align-items: center;
        gap: 8px;
        transition: background var(--transition), border-color var(--transition);
      }
      .sim-picker__chip-dot {
        width: 8px;
        height: 8px;
        border-radius: 50%;
        background: var(--chip-color);
      }
      .sim-picker__chip-role {
        text-transform: uppercase;
        letter-spacing: 0.05em;
        font-size: 10px;
        color: var(--chip-color);
        font-weight: 700;
      }
      .sim-picker__chip-name { color: var(--text-secondary); }
      .sim-picker__chip.is-on {
        background: var(--bg-hover);
        border-color: var(--chip-color);
      }
      .sim-picker__chip.is-on .sim-picker__chip-name { color: var(--text-primary); }
      .sim-empty {
        text-align: center;
        padding: 60px 20px;
        color: var(--text-muted);
      }
      .sim-empty__icon { font-size: 48px; margin-bottom: 12px; opacity: 0.5; }
      .sim-empty__text { font-size: 14px; }

      .sim-grid {
        display: grid;
        grid-template-columns: repeat(var(--sim-cols), 1fr);
        gap: 16px;
        padding: 16px 0;
      }

      .phone-frame {
        background: #000;
        border-radius: 32px;
        padding: 12px 8px 16px;
        position: relative;
        box-shadow:
          0 0 0 2px #1a1a1a,
          0 0 0 3px #333,
          0 18px 40px rgba(0,0,0,0.6);
        aspect-ratio: 9 / 18;
        display: flex;
        flex-direction: column;
        min-height: 540px;
      }
      .phone-frame__notch {
        width: 90px;
        height: 18px;
        background: #000;
        border-radius: 0 0 12px 12px;
        position: absolute;
        top: 0;
        left: 50%;
        transform: translateX(-50%);
        z-index: 3;
      }
      .phone-frame__label {
        font-size: 10px;
        font-weight: 700;
        color: white;
        text-transform: uppercase;
        letter-spacing: 0.06em;
        padding: 4px 10px;
        border-radius: 999px;
        position: absolute;
        top: -10px;
        left: 12px;
        z-index: 4;
        max-width: calc(100% - 24px);
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
        box-shadow: 0 4px 12px rgba(0,0,0,0.4);
      }
      .phone-frame__screen {
        flex: 1;
        background: var(--bg-primary);
        border-radius: 22px;
        overflow: hidden;
        margin-top: 12px;
      }
      .phone-frame__screen iframe {
        width: 100%;
        height: 100%;
        border: none;
        display: block;
      }

      @media (max-width: 900px) {
        .sim-grid { grid-template-columns: 1fr 1fr !important; }
      }
      @media (max-width: 600px) {
        .sim-grid { grid-template-columns: 1fr !important; }
      }
    </style>
    """
  end
end
