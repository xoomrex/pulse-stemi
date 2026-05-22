defmodule StemiWeb.Cardio.ReviewLive do
  use StemiWeb, :live_view

  alias Stemi.Cases
  alias Stemi.Cases.Case
  import StemiWeb.Components.StatsGrid
  use StemiWeb.EmsMapHelpers

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Cases.subscribe()

    cases = Cases.list_cardio_cases_for_list()

    socket =
      socket
      |> assign(:page_title, "Case Review")
      |> assign(:active_tab, :dashboard)
      |> assign(:cases, cases)
      |> assign(:selected_case, nil)
      |> assign(:preview_image, nil)
      |> assign(:stats, Cases.case_stats())
      |> assign(:show_map, false)

    {:ok, socket}
  end

  # Real-time update — only react to events that change the cardio list
  @impl true
  def handle_info({event, _payload}, socket) when event in [:case_er_updated, :case_cardiology_updated] do
    cases = Cases.list_cardio_cases_for_list()

    socket =
      socket
      |> assign(:cases, cases)
      |> assign(:stats, Cases.case_stats())
      |> push_event("play-alert", %{})

    {:noreply, socket}
  end

  # New comment on the case currently open in the modal — push a fresh tree
  # into the live_component so it re-renders.
  @impl true
  def handle_info({:comment_added, comment}, socket) do
    case socket.assigns.selected_case do
      %{id: id} when id == comment.case_id ->
        Phoenix.LiveView.send_update(StemiWeb.Components.CaseComments,
          id: "comments-#{id}",
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
    selected = Cases.get_case!(id)
    {:noreply, assign(socket, selected_case: selected)}
  end

  @impl true
  def handle_event("close_case", _params, socket) do
    if prev = socket.assigns.selected_case, do: Cases.unsubscribe_comments(prev.id)
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
  def handle_event("approve", %{"id" => id}, socket) do
    user = socket.assigns.current_user
    case_record = Cases.get_case!(id)

    {:ok, _} = Cases.update_case_cardiology(case_record, %{
      cardiologist_id: user.id,
      cardiology_decision: "approved",
      cardiology_decided_at: DateTime.truncate(DateTime.utc_now(), :second),
      status: "approved"
    })

    cases = Cases.list_cardio_cases_for_list()

    socket =
      socket
      |> put_flash(:info, "Case approved!")
      |> assign(:cases, cases)
      |> assign(:selected_case, nil)

    {:noreply, socket}
  end

  @impl true
  def handle_event("reject", %{"id" => id}, socket) do
    user = socket.assigns.current_user
    case_record = Cases.get_case!(id)

    {:ok, _} = Cases.update_case_cardiology(case_record, %{
      cardiologist_id: user.id,
      cardiology_decision: "rejected",
      cardiology_decided_at: DateTime.truncate(DateTime.utc_now(), :second),
      status: "rejected"
    })

    cases = Cases.list_cardio_cases_for_list()

    socket =
      socket
      |> put_flash(:info, "Case rejected.")
      |> assign(:cases, cases)
      |> assign(:selected_case, nil)

    {:noreply, socket}
  end

  defp status_color("pending_review"), do: "#f59e0b"
  defp status_color("approved"), do: "#22c55e"
  defp status_color("rejected"), do: "#ef4444"
  defp status_color("dispatched"), do: "#3b82f6"
  defp status_color(_), do: "#6b7280"

  defp status_label("pending_review"), do: "Pending"
  defp status_label("approved"), do: "Approved"
  defp status_label("rejected"), do: "Rejected"
  defp status_label("dispatched"), do: "Dispatched"
  defp status_label(s), do: s

  defp format_datetime(nil), do: "—"
  defp format_datetime(dt), do: Calendar.strftime(dt, "%d %b %Y, %H:%M")

  defp time_ago(datetime) do
    diff = DateTime.diff(DateTime.utc_now(), datetime, :minute)

    cond do
      diff < 1 -> "Just now"
      diff < 60 -> "#{diff}m ago"
      diff < 1440 -> "#{div(diff, 60)}h ago"
      true -> "#{div(diff, 1440)}d ago"
    end
  end

  defp pending_count(cases) do
    Enum.count(cases, fn c -> c.cardiology_decision == nil end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="section-header">
      <div>
        <h1 class="section-header__title">Case Review</h1>
        <span class="section-header__count">{pending_count(@cases)} pending · {length(@cases)} total</span>
      </div>
    </div>

    <.stats_grid stats={@stats} />

    <!-- Case List -->
    <div class="user-list" id="review-list">
      <div
        :for={c <- @cases}
        class="case-card"
        style={"--card-accent: #{status_color(c.status)}"}
        phx-click="view_case"
        phx-value-id={c.id}
        id={"review-#{c.id}"}
      >
        <div class="case-card__header">
          <span class="case-card__id">{Case.display_id(c)}</span>
          <span class="case-card__time">{time_ago(c.inserted_at)}</span>
        </div>
        <div class="case-card__route">
          <div class="case-card__origin">
            <div class="case-card__code">PHC</div>
            <div class="case-card__sublabel">{c.phc_user.full_name}</div>
          </div>
          <div class="case-card__arrow">
            <div class="case-card__arrow-line"></div>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><path d="M22 12h-4l-3 9L9 3l-3 9H2"/></svg>
            <div class="case-card__arrow-line"></div>
          </div>
          <div class="case-card__dest">
            <div class="case-card__code">KFMC</div>
            <div class="case-card__sublabel">Cardiology</div>
          </div>
        </div>
        <div class="case-card__footer">
          <span class="badge" style={"background: #{status_color(c.status)}22; color: #{status_color(c.status)}"}>
            {status_label(c.status)}
          </span>
          <span :if={c.ecg_photo_url && c.ecg_photo_url != "no_photo"} style="color: var(--success);">📷 ECG</span>
          <span :if={c.status == "er_approved" && c.cardiology_decision == nil} style="color: var(--warning); font-weight: 600; margin-left: auto;">REVIEW →</span>
          <span :if={c.status == "approved" || c.cardiology_decision == "approved"} style="color: #22c55e; font-weight: 600; margin-left: auto;">✓ APPROVED</span>
          <span :if={c.status == "rejected" || c.cardiology_decision == "rejected"} style="color: #ef4444; font-weight: 600; margin-left: auto;">✕ REJECTED</span>
          <span :if={c.status == "dispatched"} style="color: #3b82f6; font-weight: 600; margin-left: auto;">🚑 DISPATCHED</span>
        </div>
      </div>

      <div :if={@cases == []} class="empty-state">
        <div class="empty-state__icon">📋</div>
        <div class="empty-state__text">No cases yet.</div>
      </div>
    </div>

    <!-- Sign Out -->
    <div style="margin-top: 24px;">
      
        
        <a href="/logout" class="btn btn--ghost btn--full" id="btn-logout">Sign Out</a>
      
    </div>

    <!-- Case Detail Modal -->
    <div :if={@selected_case} style="position: fixed; inset: 0; background: rgba(0,0,0,0.7); z-index: 1000; display: flex; align-items: flex-end; justify-content: center;" id="case-detail-modal">
      <div style="background: var(--bg-secondary, #1a1a2e); border-radius: 16px 16px 0 0; padding: 20px 20px 32px; width: 100%; max-width: 500px; max-height: 85vh; overflow-y: auto; position: relative; z-index: 1001;">
        <div style="width: 40px; height: 4px; background: rgba(255,255,255,0.2); border-radius: 2px; margin: 0 auto 16px;"></div>
        <h2 style="font-size: 18px; font-weight: 700; margin-bottom: 16px;">{Case.display_id(@selected_case)}</h2>

        <div class="case-detail">
          <div class="case-detail-field">
            <span class="case-detail-label">Patient ID</span>
            <span class="case-detail-value">{@selected_case.patient_id}</span>
          </div>

          <div class="case-detail-field">
            <span class="case-detail-label">Submitted By</span>
            <span class="case-detail-value">{@selected_case.phc_user.full_name}</span>
          </div>

          <div class="case-detail-field">
            <span class="case-detail-label">Status</span>
            <span class="case-detail-value" style={"color: #{status_color(@selected_case.status)}"}>{status_label(@selected_case.status)}</span>
          </div>

          <div class="case-detail-field">
            <span class="case-detail-label">Submitted</span>
            <span class="case-detail-value">{time_ago(@selected_case.inserted_at)}</span>
          </div>

          <!-- ECG Image -->
          <div :if={@selected_case.ecg_photo_url && @selected_case.ecg_photo_url != "no_photo"} class="case-detail-photo">
            <span class="case-detail-label">ECG Photo (tap to enlarge)</span>
            <img src={@selected_case.ecg_photo_url} alt="ECG" class="case-photo-img" phx-click="preview_image" phx-value-url={@selected_case.ecg_photo_url} style="cursor: pointer;" />
          </div>

          <div :if={!@selected_case.ecg_photo_url || @selected_case.ecg_photo_url == "no_photo"} class="case-detail-field">
            <span class="case-detail-label">ECG Photo</span>
            <span class="case-detail-value" style="color: var(--text-muted);">Not provided</span>
          </div>

          <!-- ID Image -->
          <div :if={@selected_case.id_photo_url} class="case-detail-photo">
            <span class="case-detail-label">Patient ID Photo (tap to enlarge)</span>
            <img src={@selected_case.id_photo_url} alt="Patient ID" class="case-photo-img" phx-click="preview_image" phx-value-url={@selected_case.id_photo_url} style="cursor: pointer;" />
          </div>
        </div>

        <!-- Timeline -->
        <div style="margin-top: 12px; padding-top: 12px; border-top: 1px solid var(--border, #333);">
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

        <!-- Threaded discussion -->
        <div style="margin-top: 12px; padding-top: 12px; border-top: 1px solid var(--border, #333);">
          <.live_component
            module={StemiWeb.Components.CaseComments}
            id={"comments-#{@selected_case.id}"}
            case_id={@selected_case.id}
            current_user={@current_user}
          />
        </div>

        <!-- Buttons only for cases needing cardio decision -->
        <div :if={@selected_case.cardiology_decision == nil} style="display: flex; gap: 8px; margin-top: 16px;">
          <button class="btn btn--danger" style="flex:1" phx-click="reject" phx-value-id={@selected_case.id}>
            ✕ Reject
          </button>
          <button class="btn btn--primary" style="flex:2; background: var(--success);" phx-click="approve" phx-value-id={@selected_case.id}>
            ✓ Approve
          </button>
        </div>

        <!-- Already decided -->
        <div :if={@selected_case.cardiology_decision != nil} style="margin-top: 16px;">
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

    <style>
      .case-detail {
        display: flex;
        flex-direction: column;
        gap: 16px;
      }

      .case-detail-field {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 10px 0;
        border-bottom: 1px solid var(--border);
      }

      .case-detail-label {
        font-size: 13px;
        color: var(--text-muted);
        font-weight: 500;
      }

      .case-detail-value {
        font-size: 15px;
        font-weight: 600;
      }

      .case-detail-photo {
        padding: 10px 0;
        border-bottom: 1px solid var(--border);
      }

      .case-detail-photo .case-detail-label {
        display: block;
        margin-bottom: 10px;
      }

      .case-photo-img {
        width: 100%;
        border-radius: var(--radius-sm);
        max-height: 300px;
        object-fit: contain;
        background: var(--bg-primary);
      }

      .cardio-pending {
        background: rgba(245, 158, 11, 0.08) !important;
        animation: pulse-border 2s ease-in-out infinite;
      }

      @keyframes pulse-border {
        0%, 100% { border-left-color: #f59e0b; }
        50% { border-left-color: #fbbf24; }
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

    <!-- Fullscreen Image Preview -->
    <div :if={@preview_image} class="img-lightbox" phx-click="close_preview" id="cardio-img-lightbox">
      <button class="img-lightbox__close" phx-click="close_preview">✕</button>
      <img src={@preview_image} alt="Preview" />
    </div>
    """
  end
end
