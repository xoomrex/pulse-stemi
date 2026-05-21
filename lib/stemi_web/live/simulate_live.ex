defmodule StemiWeb.SimulateLive do
  @moduledoc """
  A single LiveView entry point for each simulator iframe. Auth + impersonation
  happens server-side via `StemiWeb.Auth.on_mount(:simulated, ...)`. Once
  mounted, this view simply renders the right role-specific page inline using
  the impersonated user as `@current_user`.

  No business logic lives here — it just dispatches to the real role view's
  render function. All authorization stays on the server.
  """
  use StemiWeb, :live_view

  alias Stemi.Cases
  alias Stemi.Cases.Case

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Cases.subscribe()

    user = socket.assigns.current_user
    cases_for_user = list_cases_for(user)

    socket =
      socket
      |> assign(:page_title, "Simulating #{user.full_name}")
      |> assign(:cases, cases_for_user)
      |> assign(:stats, Cases.case_stats())
      |> assign(:selected_case, nil)

    {:ok, socket, layout: false}
  end

  @impl true
  def handle_info({event, _}, socket) when event in [:case_created, :case_er_updated, :case_cardiology_updated, :case_eligibility_updated, :case_ems_dispatched, :case_comment_added] do
    {:noreply, assign(socket, :cases, list_cases_for(socket.assigns.current_user))}
  end

  @impl true
  def handle_info({:comment_added, comment}, socket) do
    case socket.assigns.selected_case do
      %{id: id} when id == comment.case_id ->
        Phoenix.LiveView.send_update(StemiWeb.Components.CaseComments,
          id: "sim-comments-#{id}",
          comments_tree: Cases.list_comments_tree(id)
        )

      _ ->
        :ok
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("view_case", %{"id" => id}, socket) do
    if prev = socket.assigns.selected_case, do: Cases.unsubscribe_comments(prev.id)
    if connected?(socket), do: Cases.subscribe_comments(id)
    {:noreply, assign(socket, :selected_case, Cases.get_case!(id))}
  end

  @impl true
  def handle_event("close_case", _params, socket) do
    if prev = socket.assigns.selected_case, do: Cases.unsubscribe_comments(prev.id)
    {:noreply, assign(socket, :selected_case, nil)}
  end

  defp list_cases_for(%{role: "phc", id: id}), do: Cases.list_cases_for_phc(id)
  defp list_cases_for(%{role: "er_consultant"}), do: Cases.list_er_cases()
  defp list_cases_for(%{role: "cardiologist"}), do: Cases.list_cardio_cases()
  defp list_cases_for(%{role: "eligibility"}), do: Cases.list_approved_cases()
  defp list_cases_for(%{role: "ems"}), do: Cases.list_ready_for_dispatch()
  defp list_cases_for(%{role: "cath_lab"}), do: Cases.list_cath_lab_cases()
  defp list_cases_for(%{role: "admin"}), do: Cases.list_all_active_cases()
  defp list_cases_for(_), do: []

  defp role_label("phc"), do: "PHC"
  defp role_label("er_consultant"), do: "ER"
  defp role_label("cardiologist"), do: "Cardio"
  defp role_label("eligibility"), do: "Eligibility"
  defp role_label("ems"), do: "EMS"
  defp role_label("cath_lab"), do: "Cath Lab"
  defp role_label("admin"), do: "Admin"
  defp role_label(r), do: r

  defp role_color("phc"), do: "#3b82f6"
  defp role_color("er_consultant"), do: "#a855f7"
  defp role_color("cardiologist"), do: "#22c55e"
  defp role_color("eligibility"), do: "#f59e0b"
  defp role_color("ems"), do: "#ef4444"
  defp role_color("cath_lab"), do: "#ec4899"
  defp role_color("admin"), do: "#6b7280"
  defp role_color(_), do: "#6b7280"

  defp status_color("pending_review"), do: "#f59e0b"
  defp status_color("pending_er"), do: "#a855f7"
  defp status_color("er_approved"), do: "#a855f7"
  defp status_color("approved"), do: "#22c55e"
  defp status_color("rejected"), do: "#ef4444"
  defp status_color("er_rejected"), do: "#ef4444"
  defp status_color("dispatched"), do: "#3b82f6"
  defp status_color("completed"), do: "#22c55e"
  defp status_color(_), do: "#6b7280"

  defp relative_time(nil), do: ""

  defp relative_time(dt) do
    diff = DateTime.diff(DateTime.utc_now(), dt, :minute)

    cond do
      diff < 1 -> "Just now"
      diff < 60 -> "#{diff}m"
      diff < 1440 -> "#{div(diff, 60)}h"
      true -> "#{div(diff, 1440)}d"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="sim-frame" data-role={@current_user.role}>
      <header class="sim-frame__header" style={"background: linear-gradient(135deg, #{role_color(@current_user.role)}33, transparent);"}>
        <div class="sim-frame__user">
          <span class="sim-frame__avatar" style={"background: #{role_color(@current_user.role)}"}>
            {String.first(@current_user.full_name || "?")}
          </span>
          <div class="sim-frame__user-info">
            <div class="sim-frame__user-name">{@current_user.full_name}</div>
            <div class="sim-frame__user-role">{role_label(@current_user.role)}</div>
          </div>
        </div>
        <span class="live-dot" title="Real PubSub subscription">Live</span>
      </header>

      <main class="sim-frame__main">
        <div class="sim-frame__cases">
          <div
            :for={c <- @cases}
            class="sim-case-card"
            phx-click="view_case"
            phx-value-id={c.id}
            style={"border-left: 3px solid #{status_color(c.status)}"}
          >
            <div class="sim-case-card__head">
              <span class="sim-case-card__id">{Case.display_id(c)}</span>
              <span class="sim-case-card__time">{relative_time(c.inserted_at)}</span>
            </div>
            <div class="sim-case-card__patient" :if={c.patient_id && c.patient_id != ""}>
              {c.patient_id}
            </div>
            <div class="sim-case-card__meta">
              <span class="sim-case-card__status" style={"color: #{status_color(c.status)}"}>{c.status}</span>
              <span class="sim-case-card__comments" :if={Cases.count_comments(c.id) > 0}>
                💬 {Cases.count_comments(c.id)}
              </span>
            </div>
          </div>

          <div :if={@cases == []} class="sim-frame__empty">
            <div class="sim-frame__empty-icon">🩺</div>
            <div class="sim-frame__empty-text">No cases for {role_label(@current_user.role)} yet</div>
          </div>
        </div>
      </main>

      <!-- Case detail / comments modal -->
      <div :if={@selected_case} class="sim-frame__modal">
        <div class="sim-frame__modal-card">
          <div class="sim-frame__modal-head">
            <div>
              <div class="sim-frame__modal-title">{Case.display_id(@selected_case)}</div>
              <div class="sim-frame__modal-sub" :if={@selected_case.patient_id && @selected_case.patient_id != ""}>
                Patient: {@selected_case.patient_id}
              </div>
            </div>
            <button type="button" class="sim-frame__modal-close" phx-click="close_case">✕</button>
          </div>

          <.live_component
            module={StemiWeb.Components.CaseComments}
            id={"sim-comments-#{@selected_case.id}"}
            case_id={@selected_case.id}
            current_user={@current_user}
          />
        </div>
      </div>
    </div>

    <style>
      body { background: var(--bg-primary); }
      .sim-frame {
        height: 100dvh;
        display: flex;
        flex-direction: column;
        background: var(--bg-primary);
        overflow: hidden;
      }
      .sim-frame__header {
        padding: 12px 14px;
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 8px;
        border-bottom: 1px solid var(--border);
      }
      .sim-frame__user { display: flex; align-items: center; gap: 10px; min-width: 0; }
      .sim-frame__avatar {
        width: 36px;
        height: 36px;
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        color: white;
        font-weight: 700;
        font-size: 15px;
        flex-shrink: 0;
      }
      .sim-frame__user-name {
        font-size: 13px;
        font-weight: 600;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
        max-width: 140px;
      }
      .sim-frame__user-role {
        font-size: 10px;
        color: var(--text-muted);
        text-transform: uppercase;
        letter-spacing: 0.05em;
      }
      .sim-frame__main {
        flex: 1;
        overflow-y: auto;
        padding: 10px;
      }
      .sim-frame__cases { display: flex; flex-direction: column; gap: 8px; }
      .sim-case-card {
        background: var(--bg-card);
        border-radius: 10px;
        padding: 10px 12px;
        cursor: pointer;
        transition: transform 0.15s ease, background 0.15s ease;
      }
      .sim-case-card:active { transform: scale(0.98); background: var(--bg-hover); }
      .sim-case-card__head { display: flex; justify-content: space-between; align-items: center; }
      .sim-case-card__id { font-size: 12px; font-weight: 700; color: var(--text-primary); }
      .sim-case-card__time { font-size: 10px; color: var(--text-muted); }
      .sim-case-card__patient { font-size: 11px; color: var(--text-secondary); margin-top: 2px; }
      .sim-case-card__meta { display: flex; gap: 8px; font-size: 10px; margin-top: 6px; align-items: center; }
      .sim-case-card__status { text-transform: uppercase; letter-spacing: 0.05em; font-weight: 600; }
      .sim-case-card__comments { color: var(--warning); }
      .sim-frame__empty {
        text-align: center;
        padding: 32px 16px;
        color: var(--text-muted);
      }
      .sim-frame__empty-icon { font-size: 32px; margin-bottom: 8px; opacity: 0.6; }
      .sim-frame__empty-text { font-size: 12px; }
      .sim-frame__modal {
        position: absolute;
        inset: 0;
        background: rgba(0,0,0,0.75);
        display: flex;
        align-items: flex-end;
        z-index: 100;
      }
      .sim-frame__modal-card {
        background: var(--bg-secondary);
        width: 100%;
        max-height: 85%;
        border-radius: 16px 16px 0 0;
        padding: 14px;
        overflow-y: auto;
      }
      .sim-frame__modal-head { display: flex; justify-content: space-between; align-items: flex-start; margin-bottom: 12px; }
      .sim-frame__modal-title { font-size: 14px; font-weight: 700; }
      .sim-frame__modal-sub { font-size: 11px; color: var(--text-muted); margin-top: 2px; }
      .sim-frame__modal-close {
        background: var(--bg-input);
        border: none;
        color: var(--text-secondary);
        width: 28px;
        height: 28px;
        border-radius: 50%;
        cursor: pointer;
        font-size: 12px;
      }
    </style>
    """
  end
end
