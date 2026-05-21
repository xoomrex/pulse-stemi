defmodule StemiWeb.Er.ReviewLive do
  use StemiWeb, :live_view

  alias Stemi.Cases
  alias Stemi.Cases.Case
  import StemiWeb.Components.StatsGrid
  use StemiWeb.EmsMapHelpers

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Cases.subscribe()

    cases = Cases.list_er_cases()

    socket =
      socket
      |> assign(:page_title, "ER Review")
      |> assign(:active_tab, :dashboard)
      |> assign(:cases, cases)
      |> assign(:selected_case, nil)
      |> assign(:preview_image, nil)
      |> assign(:stats, Cases.case_stats())
      |> assign(:show_map, false)

    {:ok, socket}
  end

  # Real-time update from PubSub
  @impl true
  def handle_info({event, _payload}, socket) when event in [:case_created, :case_er_updated, :case_cardiology_updated, :case_eligibility_updated, :case_ems_dispatched] do
    cases = Cases.list_er_cases()

    socket =
      socket
      |> assign(:cases, cases)
      |> assign(:stats, Cases.case_stats())
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
  def handle_event("preview_image", %{"url" => url}, socket) do
    {:noreply, assign(socket, preview_image: url)}
  end

  @impl true
  def handle_event("close_preview", _params, socket) do
    {:noreply, assign(socket, preview_image: nil)}
  end

  @impl true
  def handle_event("forward_to_cardio", %{"id" => id}, socket) do
    user = socket.assigns.current_user
    case_record = Cases.get_case!(id)

    {:ok, _} = Cases.update_case_er(case_record, %{
      er_consultant_id: user.id,
      er_decision: "approved",
      er_decided_at: DateTime.truncate(DateTime.utc_now(), :second),
      status: "er_approved"
    })

    cases = Cases.list_er_cases()

    socket =
      socket
      |> put_flash(:info, "Case forwarded to Cardiology!")
      |> assign(:cases, cases)
      |> assign(:selected_case, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("reject", %{"id" => id}, socket) do
    user = socket.assigns.current_user
    case_record = Cases.get_case!(id)

    {:ok, _} = Cases.update_case_er(case_record, %{
      er_consultant_id: user.id,
      er_decision: "rejected",
      er_decided_at: DateTime.truncate(DateTime.utc_now(), :second),
      status: "er_rejected"
    })

    cases = Cases.list_er_cases()

    socket =
      socket
      |> put_flash(:info, "Case rejected.")
      |> assign(:cases, cases)
      |> assign(:selected_case, nil)

    {:noreply, socket}
  end

  defp status_color("pending_review"), do: "#f59e0b"
  defp status_color("pending_er"), do: "#f59e0b"
  defp status_color("er_approved"), do: "#22c55e"
  defp status_color("er_rejected"), do: "#ef4444"
  defp status_color("approved"), do: "#22c55e"
  defp status_color("rejected"), do: "#ef4444"
  defp status_color("dispatched"), do: "#3b82f6"
  defp status_color(_), do: "#6b7280"

  defp status_label("pending_review"), do: "New Case"
  defp status_label("pending_er"), do: "New Case"
  defp status_label("er_approved"), do: "Sent to Cardio"
  defp status_label("er_rejected"), do: "Rejected"
  defp status_label("approved"), do: "Cardio Approved"
  defp status_label("rejected"), do: "Cardio Rejected"
  defp status_label("dispatched"), do: "Dispatched"
  defp status_label(s), do: s

  defp time_ago(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :minute)

    cond do
      diff < 1 -> "Just now"
      diff < 60 -> "#{diff}m ago"
      diff < 1440 -> "#{div(diff, 60)}h ago"
      true -> "#{div(diff, 1440)}d ago"
    end
  end

  defp format_datetime(nil), do: "—"
  defp format_datetime(dt) do
    Calendar.strftime(dt, "%d %b %Y, %H:%M")
  end

  defp pending_count(cases), do: Enum.count(cases, & &1.status in ["pending_review", "pending_er"])

  @impl true
  def render(assigns) do
    ~H"""
    <style>
      .er-overlay {
        position: fixed;
        inset: 0;
        background: rgba(0,0,0,0.7);
        z-index: 1000;
        display: flex;
        align-items: flex-end;
        justify-content: center;
      }
      .er-panel {
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
      .er-panel__handle {
        width: 40px;
        height: 4px;
        background: rgba(255,255,255,0.2);
        border-radius: 2px;
        margin: 0 auto 16px;
      }
      .er-panel__title {
        font-size: 18px;
        font-weight: 700;
        margin-bottom: 16px;
      }
      .er-field {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 10px 0;
        border-bottom: 1px solid var(--border, #333);
      }
      .er-label { font-size: 13px; color: var(--text-muted, #888); font-weight: 500; }
      .er-val { font-size: 15px; font-weight: 600; }
      .er-photo { padding: 10px 0; border-bottom: 1px solid var(--border, #333); }
      .er-photo .er-label { display: block; margin-bottom: 10px; }
      .er-photo img { width: 100%; border-radius: 8px; max-height: 250px; object-fit: contain; background: var(--bg-primary, #0f0f23); cursor: pointer; }
      .er-btns { display: flex; gap: 8px; margin-top: 16px; }
      .img-lightbox { position: fixed; inset: 0; background: rgba(0,0,0,0.92); z-index: 2000; display: flex; align-items: center; justify-content: center; cursor: pointer; }
      .img-lightbox img { max-width: 95vw; max-height: 90vh; object-fit: contain; border-radius: 8px; }
      .img-lightbox__close { position: absolute; top: 16px; right: 16px; background: rgba(255,255,255,0.1); border: none; color: white; width: 40px; height: 40px; border-radius: 50%; font-size: 20px; cursor: pointer; display: flex; align-items: center; justify-content: center; }
    </style>

    <div class="section-header">
      <div>
        <h1 class="section-header__title">ER Review</h1>
        <span class="section-header__count">{pending_count(@cases)} new · {length(@cases)} total</span>
      </div>
    </div>

    <.stats_grid stats={@stats} />

    <!-- Case List -->
    <div class="user-list" id="er-list">
      <div
        :for={c <- @cases}
        class="user-card"
        style="cursor: pointer;"
        phx-click="view_case"
        phx-value-id={c.id}
        id={"er-#{c.id}"}
      >
        <div class="user-card__avatar" style={"background: #{status_color(c.status)}"}>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M22 12h-4l-3 9L9 3l-3 9H2"/>
          </svg>
        </div>
        <div class="user-card__info">
          <div class="user-card__name">{Case.display_id(c)} — {c.patient_id}</div>
          <div class="user-card__meta">
            <span class="badge" style={"background: #{status_color(c.status)}22; color: #{status_color(c.status)}"}>
              {status_label(c.status)}
            </span>
            <span class="badge badge--phc">From: {c.phc_user.full_name}</span>
            <span style="color: var(--text-muted); font-size: 12px;">{time_ago(c.inserted_at)}</span>
          </div>
        </div>
        <div :if={c.status == "pending_review"} style="color: var(--warning); font-size: 12px; font-weight: 600;">REVIEW →</div>
        <div :if={c.status == "er_approved"} style="color: #22c55e; font-size: 12px; font-weight: 600;">✓ FORWARDED</div>
        <div :if={c.status == "er_rejected"} style="color: #ef4444; font-size: 12px; font-weight: 600;">✕ REJECTED</div>
        <div :if={c.status not in ~w(pending_review er_approved er_rejected)} style="color: #3b82f6; font-size: 12px; font-weight: 600;">IN PROGRESS</div>
      </div>

      <div :if={@cases == []} class="empty-state">
        <div class="empty-state__icon">🏥</div>
        <div class="empty-state__text">No cases yet.</div>
      </div>
    </div>

    <!-- Sign Out -->
    <div style="margin-top: 24px;">
      
        
        <a href="/logout" class="btn btn--ghost btn--full" id="btn-logout">Sign Out</a>
      
    </div>

    <!-- Case Detail Modal -->
    <div :if={@selected_case} class="er-overlay" id="er-detail-modal">
      <div class="er-panel">
        <div class="er-panel__handle"></div>
        <h2 class="er-panel__title">{Case.display_id(@selected_case)}</h2>

        <div class="er-field">
          <span class="er-label">Patient ID</span>
          <span class="er-val">{@selected_case.patient_id}</span>
        </div>

        <div class="er-field">
          <span class="er-label">Submitted By</span>
          <span class="er-val">{@selected_case.phc_user.full_name}</span>
        </div>

        <div class="er-field">
          <span class="er-label">Status</span>
          <span class="er-val" style={"color: #{status_color(@selected_case.status)}"}>{status_label(@selected_case.status)}</span>
        </div>

        <div class="er-field">
          <span class="er-label">Created</span>
          <span class="er-val" style="font-size: 13px;">{format_datetime(@selected_case.inserted_at)}</span>
        </div>

        <!-- ECG Image -->
        <div :if={@selected_case.ecg_photo_url && @selected_case.ecg_photo_url != "no_photo"} class="er-photo">
          <span class="er-label">ECG Photo</span>
          <img src={@selected_case.ecg_photo_url} alt="ECG" phx-click="preview_image" phx-value-url={@selected_case.ecg_photo_url} style="cursor: pointer;" title="Tap to enlarge" />
        </div>

        <!-- ID Image -->
        <div :if={@selected_case.id_photo_url} class="er-photo">
          <span class="er-label">Patient ID Photo</span>
          <img src={@selected_case.id_photo_url} alt="Patient ID" phx-click="preview_image" phx-value-url={@selected_case.id_photo_url} style="cursor: pointer;" title="Tap to enlarge" />
        </div>

        <!-- Timeline -->
        <div class="timeline-section" style="margin-top: 12px; padding-top: 12px; border-top: 1px solid var(--border, #333);">
          <div style="font-size: 13px; color: var(--text-muted); font-weight: 600; margin-bottom: 8px;">Timeline</div>
          <div style="display: flex; align-items: center; gap: 8px; padding: 6px 0;">
            <div style="width: 8px; height: 8px; border-radius: 50%; background: #22c55e; flex-shrink: 0;"></div>
            <span style="font-size: 13px; flex: 1;">Created by {if @selected_case.phc_user, do: @selected_case.phc_user.full_name, else: "?"}</span>
            <span style="font-size: 11px; color: var(--text-muted);">{format_datetime(@selected_case.inserted_at)}</span>
          </div>
          <div :if={@selected_case.er_decided_at} style="display: flex; align-items: center; gap: 8px; padding: 6px 0;">
            <div style={"width: 8px; height: 8px; border-radius: 50%; background: #{if @selected_case.er_decision == "approved", do: "#a855f7", else: "#ef4444"}; flex-shrink: 0;"}></div>
            <span style="font-size: 13px; flex: 1;">ER {if @selected_case.er_decision == "approved", do: "Forwarded", else: "Rejected"}</span>
            <span style="font-size: 11px; color: var(--text-muted);">{format_datetime(@selected_case.er_decided_at)}</span>
          </div>
          <div :if={@selected_case.cardiology_decided_at} style="display: flex; align-items: center; gap: 8px; padding: 6px 0;">
            <div style={"width: 8px; height: 8px; border-radius: 50%; background: #{if @selected_case.cardiology_decision == "approved", do: "#22c55e", else: "#ef4444"}; flex-shrink: 0;"}></div>
            <span style="font-size: 13px; flex: 1;">Cardio {if @selected_case.cardiology_decision == "approved", do: "Approved", else: "Rejected"}</span>
            <span style="font-size: 11px; color: var(--text-muted);">{format_datetime(@selected_case.cardiology_decided_at)}</span>
          </div>
          <div :if={@selected_case.eligibility_decided_at} style="display: flex; align-items: center; gap: 8px; padding: 6px 0;">
            <div style="width: 8px; height: 8px; border-radius: 50%; background: #f59e0b; flex-shrink: 0;"></div>
            <span style="font-size: 13px; flex: 1;">MRN: {@selected_case.mrn_number || "—"}</span>
            <span style="font-size: 11px; color: var(--text-muted);">{format_datetime(@selected_case.eligibility_decided_at)}</span>
          </div>
          <div :if={@selected_case.ems_dispatched_at} style="display: flex; align-items: center; gap: 8px; padding: 6px 0;">
            <div style="width: 8px; height: 8px; border-radius: 50%; background: #3b82f6; flex-shrink: 0;"></div>
            <span style="font-size: 13px; flex: 1;">EMS Dispatched</span>
            <span style="font-size: 11px; color: var(--text-muted);">{format_datetime(@selected_case.ems_dispatched_at)}</span>
          </div>
          <div :if={@selected_case.cath_lab_confirmed_at} style="display: flex; align-items: center; gap: 8px; padding: 6px 0;">
            <div style="width: 8px; height: 8px; border-radius: 50%; background: #ec4899; flex-shrink: 0;"></div>
            <span style="font-size: 13px; flex: 1;">Cath Lab Ready</span>
            <span style="font-size: 11px; color: var(--text-muted);">{format_datetime(@selected_case.cath_lab_confirmed_at)}</span>
          </div>
        </div>

        <!-- Buttons only for pending cases -->
        <div :if={@selected_case.status in ["pending_review", "pending_er"]} class="er-btns">
          <button class="btn btn--danger" style="flex:1" phx-click="reject" phx-value-id={@selected_case.id}>
            ✕ Reject
          </button>
          <button class="btn btn--primary" style="flex:2; background: var(--success);" phx-click="forward_to_cardio" phx-value-id={@selected_case.id}>
            ✓ Forward to Cardiology
          </button>
        </div>

        <!-- Already decided -->
        <div :if={@selected_case.status not in ["pending_review", "pending_er"]} style="margin-top: 16px;">
          <!-- EMS Live Tracking -->
          <div :if={@selected_case.status == "dispatched"} style="margin-bottom: 12px;" id="ems-map-hook" phx-hook="EmsMap">
            <button type="button" class="btn btn--full" style={"background: #{if @show_map, do: "#6b7280", else: "#3b82f6"}; color: white; display: flex; align-items: center; justify-content: center; gap: 8px; font-weight: 600;"} phx-click="toggle_map">
              {if @show_map, do: "✕ Close Map", else: "🚑 Track EMS Live"}
            </button>
            <div id="ems-map-container" style={"margin-top: 8px; border-radius: 12px; overflow: hidden; #{if !@show_map, do: "display:none;"}"}></div>
          </div>
          <button type="button" class="btn btn--ghost btn--full" phx-click="close_case">Close</button>
        </div>
      </div>
    </div>

    <!-- Fullscreen Image Preview -->
    <div :if={@preview_image} class="img-lightbox" phx-click="close_preview" id="er-img-lightbox">
      <button class="img-lightbox__close" phx-click="close_preview">✕</button>
      <img src={@preview_image} alt="Preview" />
    </div>
    """
  end
end
