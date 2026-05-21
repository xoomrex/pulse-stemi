defmodule StemiWeb.Admin.CasesLive do
  use StemiWeb, :live_view

  alias Stemi.Cases
  alias Stemi.Cases.Case

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Cases.subscribe()

    cases = Cases.list_all_cases()

    socket =
      socket
      |> assign(:page_title, "All Cases")
      |> assign(:active_tab, :cases)
      |> assign(:cases, cases)
      |> assign(:selected_case, nil)
      |> assign(:filter_status, "all")
      |> assign(:preview_image, nil)

    {:ok, socket}
  end

  # Real-time update from PubSub
  @impl true
  def handle_info({event, _payload}, socket) when event in [:case_created, :case_er_updated, :case_cardiology_updated, :case_eligibility_updated, :case_ems_dispatched, :case_cath_lab_updated] do
    cases = Cases.list_all_cases()

    socket =
      socket
      |> assign(:cases, cases)
      |> push_event("play-alert", %{})

    {:noreply, socket}
  end

  @impl true
  def handle_event("view_case", %{"id" => id}, socket) do
    selected = Cases.get_case!(id)
    {:noreply, assign(socket, selected_case: selected)}
  end

  @impl true
  def handle_event("close_case", _params, socket) do
    {:noreply, assign(socket, selected_case: nil)}
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    {:noreply, assign(socket, :filter_status, status)}
  end

  @impl true
  def handle_event("preview_image", %{"url" => url}, socket) do
    {:noreply, assign(socket, preview_image: url)}
  end

  @impl true
  def handle_event("close_preview", _params, socket) do
    {:noreply, assign(socket, preview_image: nil)}
  end

  # --- Helpers ---

  defp filtered_cases(cases, "all"), do: cases
  defp filtered_cases(cases, "deleted"), do: Enum.filter(cases, & &1.is_deleted)
  defp filtered_cases(cases, status), do: Enum.filter(cases, &(&1.status == status))

  defp status_color("pending_review"), do: "#f59e0b"
  defp status_color("pending_er"), do: "#f59e0b"
  defp status_color("er_approved"), do: "#a855f7"
  defp status_color("er_rejected"), do: "#ef4444"
  defp status_color("approved"), do: "#22c55e"
  defp status_color("rejected"), do: "#ef4444"
  defp status_color("dispatched"), do: "#3b82f6"
  defp status_color("completed"), do: "#10b981"
  defp status_color(_), do: "#6b7280"

  defp status_label("pending_review"), do: "Pending ER"
  defp status_label("pending_er"), do: "Pending ER"
  defp status_label("er_approved"), do: "ER Approved"
  defp status_label("er_rejected"), do: "ER Rejected"
  defp status_label("approved"), do: "Cardio Approved"
  defp status_label("rejected"), do: "Cardio Rejected"
  defp status_label("dispatched"), do: "Dispatched"
  defp status_label("completed"), do: "Completed"
  defp status_label(s), do: s

  defp status_icon("pending_review"), do: "⏳"
  defp status_icon("pending_er"), do: "⏳"
  defp status_icon("er_approved"), do: "🏥"
  defp status_icon("er_rejected"), do: "✕"
  defp status_icon("approved"), do: "✓"
  defp status_icon("rejected"), do: "✕"
  defp status_icon("dispatched"), do: "🚑"
  defp status_icon("completed"), do: "✓✓"
  defp status_icon(_), do: "?"

  defp time_ago(nil), do: "—"
  defp time_ago(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :minute)

    cond do
      diff < 1 -> "Just now"
      diff < 60 -> "#{diff}m ago"
      diff < 1440 -> "#{div(diff, 60)}h ago"
      true -> "#{div(diff, 1440)}d ago"
    end
  end

  defp count_by_status(cases, status), do: Enum.count(cases, &(&1.status == status))
  defp count_deleted(cases), do: Enum.count(cases, & &1.is_deleted)

  @impl true
  def render(assigns) do
    ~H"""
    <style>
      .admin-cases-stats {
        display: grid;
        grid-template-columns: repeat(3, 1fr);
        gap: 8px;
        margin-bottom: 16px;
      }
      .stat-card {
        background: var(--bg-secondary);
        border-radius: 10px;
        padding: 10px;
        text-align: center;
        border: 1px solid var(--border);
      }
      .stat-card__num {
        font-size: 22px;
        font-weight: 800;
        line-height: 1;
      }
      .stat-card__label {
        font-size: 11px;
        color: var(--text-muted);
        margin-top: 4px;
      }
      .admin-case-overlay {
        position: fixed;
        inset: 0;
        background: rgba(0,0,0,0.7);
        z-index: 1000;
        display: flex;
        align-items: flex-end;
        justify-content: center;
      }
      .admin-case-panel {
        background: var(--bg-secondary, #1a1a2e);
        border-radius: 16px 16px 0 0;
        padding: 20px 20px 32px;
        width: 100%;
        max-width: 500px;
        max-height: 85vh;
        overflow-y: auto;
        position: relative;
        z-index: 1001;
      }
      .admin-case-panel__handle {
        width: 40px;
        height: 4px;
        background: rgba(255,255,255,0.2);
        border-radius: 2px;
        margin: 0 auto 16px;
      }
      .admin-case-panel__title {
        font-size: 18px;
        font-weight: 700;
        margin-bottom: 16px;
      }
      .afield {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 10px 0;
        border-bottom: 1px solid var(--border, #333);
      }
      .afield-label { font-size: 13px; color: var(--text-muted, #888); font-weight: 500; }
      .afield-val { font-size: 14px; font-weight: 600; }
      .aphoto { padding: 10px 0; border-bottom: 1px solid var(--border, #333); }
      .aphoto .afield-label { display: block; margin-bottom: 8px; }
      .aphoto img {
        width: 100%;
        border-radius: 8px;
        max-height: 250px;
        object-fit: contain;
        background: var(--bg-primary, #0f0f23);
        cursor: pointer;
      }
      .timeline-section {
        margin-top: 12px;
        padding-top: 12px;
        border-top: 1px solid var(--border, #333);
      }
      .timeline-title {
        font-size: 13px;
        color: var(--text-muted);
        font-weight: 600;
        margin-bottom: 8px;
      }
      .timeline-item {
        display: flex;
        align-items: center;
        gap: 8px;
        padding: 6px 0;
      }
      .timeline-dot {
        width: 8px;
        height: 8px;
        border-radius: 50%;
        flex-shrink: 0;
      }
      .timeline-text {
        font-size: 13px;
        flex: 1;
      }
      .timeline-time {
        font-size: 11px;
        color: var(--text-muted);
      }
      .deleted-badge {
        background: rgba(239, 68, 68, 0.15);
        color: #ef4444;
        padding: 2px 8px;
        border-radius: 4px;
        font-size: 11px;
        font-weight: 700;
      }
      .img-lightbox {
        position: fixed;
        inset: 0;
        background: rgba(0,0,0,0.92);
        z-index: 2000;
        display: flex;
        align-items: center;
        justify-content: center;
        cursor: pointer;
      }
      .img-lightbox img {
        max-width: 95vw;
        max-height: 90vh;
        object-fit: contain;
        border-radius: 8px;
      }
      .img-lightbox__close {
        position: absolute;
        top: 16px;
        right: 16px;
        background: rgba(255,255,255,0.1);
        border: none;
        color: white;
        width: 40px;
        height: 40px;
        border-radius: 50%;
        font-size: 20px;
        cursor: pointer;
        display: flex;
        align-items: center;
        justify-content: center;
      }
    </style>

    <div class="section-header">
      <div>
        <h1 class="section-header__title">All Cases</h1>
        <span class="section-header__count">{length(@cases)} total cases</span>
      </div>
      <a href="/admin/users" class="btn btn--ghost btn--sm">👤 Users</a>
    </div>

    <!-- Stats Grid -->
    <div class="admin-cases-stats">
      <div class="stat-card">
        <div class="stat-card__num" style="color: #f59e0b;">{count_by_status(@cases, "pending_review")}</div>
        <div class="stat-card__label">Pending</div>
      </div>
      <div class="stat-card">
        <div class="stat-card__num" style="color: #a855f7;">{count_by_status(@cases, "er_approved")}</div>
        <div class="stat-card__label">ER Approved</div>
      </div>
      <div class="stat-card">
        <div class="stat-card__num" style="color: #22c55e;">{count_by_status(@cases, "approved")}</div>
        <div class="stat-card__label">Approved</div>
      </div>
      <div class="stat-card">
        <div class="stat-card__num" style="color: #3b82f6;">{count_by_status(@cases, "dispatched")}</div>
        <div class="stat-card__label">Dispatched</div>
      </div>
      <div class="stat-card">
        <div class="stat-card__num" style="color: #ef4444;">{count_by_status(@cases, "rejected") + count_by_status(@cases, "er_rejected")}</div>
        <div class="stat-card__label">Rejected</div>
      </div>
      <div class="stat-card">
        <div class="stat-card__num" style="color: #ef4444;">{count_deleted(@cases)}</div>
        <div class="stat-card__label">Deleted</div>
      </div>
    </div>

    <!-- Status Filter Tabs -->
    <div class="tabs" id="status-tabs">
      <button
        class={"tab #{if @filter_status == "all", do: "tab--active"}"}
        phx-click="filter_status"
        phx-value-status="all"
      >All</button>
      <button
        :for={status <- ~w(pending_review er_approved approved dispatched rejected er_rejected deleted)}
        class={"tab #{if @filter_status == status, do: "tab--active"}"}
        phx-click="filter_status"
        phx-value-status={status}
      >{if status == "deleted", do: "Deleted", else: status_label(status)}</button>
    </div>

    <!-- Case List -->
    <div class="user-list" id="admin-cases-list">
      <div
        :for={c <- filtered_cases(@cases, @filter_status)}
        class="user-card"
        style={"cursor: pointer; border-left: 4px solid #{status_color(c.status)}; #{if c.is_deleted, do: "opacity: 0.6;", else: ""}"}
        phx-click="view_case"
        phx-value-id={c.id}
        id={"admin-case-#{c.id}"}
      >
        <div class="user-card__avatar" style={"background: #{status_color(c.status)}"}>
          {status_icon(c.status)}
        </div>
        <div class="user-card__info">
          <div class="user-card__name">{Case.display_id(c)} — {c.patient_id}</div>
          <div class="user-card__meta">
            <span class="badge" style={"background: #{status_color(c.status)}22; color: #{status_color(c.status)}"}>
              {status_label(c.status)}
            </span>
            <span :if={c.is_deleted} class="deleted-badge">DELETED</span>
            <span :if={c.phc_user} class="badge badge--phc">From: {c.phc_user.full_name}</span>
            <span style="color: var(--text-muted); font-size: 12px;">{time_ago(c.inserted_at)}</span>
          </div>
        </div>
        <div style={"color: #{status_color(c.status)}; font-size: 12px; font-weight: 600;"}>{status_label(c.status)}</div>
      </div>

      <div :if={filtered_cases(@cases, @filter_status) == []} class="empty-state">
        <div class="empty-state__icon">📋</div>
        <div class="empty-state__text">No cases matching this filter.</div>
      </div>
    </div>

    <!-- Sign Out -->
    <div style="margin-top: 24px;">
      <form action="/logout" method="post">
        <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />
        <button type="submit" class="btn btn--ghost btn--full" id="btn-logout">Sign Out</button>
      </form>
    </div>

    <!-- Case Detail Modal -->
    <div :if={@selected_case} class="admin-case-overlay" id="admin-case-detail-modal">
      <div class="admin-case-panel">
        <div class="admin-case-panel__handle"></div>
        <h2 class="admin-case-panel__title">{Case.display_id(@selected_case)}</h2>

        <div :if={@selected_case.is_deleted} style="margin-bottom: 12px;">
          <span class="deleted-badge" style="font-size: 13px; padding: 4px 12px;">⚠ This case has been soft-deleted</span>
        </div>

        <div class="afield">
          <span class="afield-label">Patient ID</span>
          <span class="afield-val">{@selected_case.patient_id}</span>
        </div>

        <div class="afield">
          <span class="afield-label">Status</span>
          <span class="afield-val" style={"color: #{status_color(@selected_case.status)}"}>{status_label(@selected_case.status)}</span>
        </div>

        <div :if={@selected_case.phc_user} class="afield">
          <span class="afield-label">Submitted By</span>
          <span class="afield-val">{@selected_case.phc_user.full_name}</span>
        </div>

        <div class="afield">
          <span class="afield-label">Submitted</span>
          <span class="afield-val">{time_ago(@selected_case.inserted_at)}</span>
        </div>

        <!-- ECG Image -->
        <div :if={@selected_case.ecg_photo_url && @selected_case.ecg_photo_url != "no_photo"} class="aphoto">
          <span class="afield-label">ECG Photo (tap to enlarge)</span>
          <img src={@selected_case.ecg_photo_url} alt="ECG" phx-click="preview_image" phx-value-url={@selected_case.ecg_photo_url} />
        </div>

        <!-- ID Image -->
        <div :if={@selected_case.id_photo_url} class="aphoto">
          <span class="afield-label">Patient ID Photo (tap to enlarge)</span>
          <img src={@selected_case.id_photo_url} alt="Patient ID" phx-click="preview_image" phx-value-url={@selected_case.id_photo_url} />
        </div>

        <!-- Timeline -->
        <div class="timeline-section">
          <div class="timeline-title">Case Timeline</div>

          <div class="timeline-item">
            <div class="timeline-dot" style="background: #22c55e;"></div>
            <span class="timeline-text">Created by {if @selected_case.phc_user, do: @selected_case.phc_user.full_name, else: "?"}</span>
            <span class="timeline-time">{time_ago(@selected_case.inserted_at)}</span>
          </div>

          <div :if={@selected_case.er_consultant} class="timeline-item">
            <div class="timeline-dot" style={"background: #{if @selected_case.er_decision == "approved", do: "#a855f7", else: "#ef4444"};"}></div>
            <span class="timeline-text">
              ER: {if @selected_case.er_decision == "approved", do: "Forwarded", else: "Rejected"} by {@selected_case.er_consultant.full_name}
            </span>
            <span class="timeline-time">{time_ago(@selected_case.er_decided_at)}</span>
          </div>

          <div :if={@selected_case.cardiologist} class="timeline-item">
            <div class="timeline-dot" style={"background: #{if @selected_case.cardiology_decision == "approved", do: "#22c55e", else: "#ef4444"};"}></div>
            <span class="timeline-text">
              Cardio: {if @selected_case.cardiology_decision == "approved", do: "Approved", else: "Rejected"} by {@selected_case.cardiologist.full_name}
            </span>
            <span class="timeline-time">{time_ago(@selected_case.cardiology_decided_at)}</span>
          </div>

          <div :if={@selected_case.eligibility} class="timeline-item">
            <div class="timeline-dot" style="background: #f59e0b;"></div>
            <span class="timeline-text">
              MRN: {@selected_case.mrn_number || "—"} by {@selected_case.eligibility.full_name}
            </span>
            <span class="timeline-time">{time_ago(@selected_case.eligibility_decided_at)}</span>
          </div>

          <div :if={@selected_case.cath_lab_user} class="timeline-item">
            <div class="timeline-dot" style={"background: #{if @selected_case.cath_lab_status == "ready", do: "#22c55e", else: "#a855f7"};"}></div>
            <span class="timeline-text">
              Cath Lab: {if @selected_case.cath_lab_status == "ready", do: "Ready", else: "Preparing"} by {@selected_case.cath_lab_user.full_name}
            </span>
            <span class="timeline-time">{time_ago(@selected_case.cath_lab_confirmed_at)}</span>
          </div>

          <div :if={@selected_case.ems_user} class="timeline-item">
            <div class="timeline-dot" style="background: #3b82f6;"></div>
            <span class="timeline-text">
              Dispatched by {@selected_case.ems_user.full_name}
            </span>
            <span class="timeline-time">{time_ago(@selected_case.ems_dispatched_at)}</span>
          </div>
        </div>

        <div style="margin-top: 16px;">
          <button type="button" class="btn btn--ghost btn--full" phx-click="close_case">Close</button>
        </div>
      </div>
    </div>

    <!-- Fullscreen Image Preview Lightbox -->
    <div :if={@preview_image} class="img-lightbox" phx-click="close_preview" id="img-lightbox">
      <button class="img-lightbox__close" phx-click="close_preview">✕</button>
      <img src={@preview_image} alt="Preview" />
    </div>
    """
  end
end
