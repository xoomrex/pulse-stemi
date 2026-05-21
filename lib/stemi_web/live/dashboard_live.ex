defmodule StemiWeb.DashboardLive do
  use StemiWeb, :live_view

  alias Stemi.Cases
  alias Stemi.Cases.Case

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Cases.subscribe()

    cases = Cases.list_all_active_cases()

    socket =
      socket
      |> assign(:page_title, "Track Cases")
      |> assign(:active_tab, :dashboard)
      |> assign(:cases, cases)
      |> assign(:selected_case, nil)
      |> assign(:filter_status, "all")
      |> assign(:preview_image, nil)
      |> assign(:mrn_value, "")
      |> assign(:show_map, false)

    {:ok, socket}
  end

  # Real-time update from PubSub
  @impl true
  def handle_info({event, _payload}, socket) when event in [:case_created, :case_er_updated, :case_cardiology_updated, :case_eligibility_updated, :case_ems_dispatched, :case_cath_lab_updated] do
    cases = Cases.list_all_active_cases()

    socket =
      socket
      |> assign(:cases, cases)
      |> push_event("play-alert", %{})

    {:noreply, socket}
  end

  # EMS location update — push to map without full reload
  @impl true
  def handle_info({:ems_location_updated, case_data}, socket) do
    if socket.assigns.show_map && socket.assigns.selected_case && socket.assigns.selected_case.id == case_data.id do
      {:noreply, push_event(socket, "update_ems_position", %{lat: case_data.ems_lat, lng: case_data.ems_lng})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("view_case", %{"id" => id}, socket) do
    selected = Cases.get_case!(id)
    {:noreply, assign(socket, selected_case: selected, mrn_value: selected.mrn_number || "")}
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

  @impl true
  def handle_event("toggle_map", _params, socket) do
    c = socket.assigns.selected_case
    if socket.assigns.show_map do
      {:noreply, socket |> assign(:show_map, false) |> push_event("hide_ems_map", %{})}
    else
      if c && c.ems_lat && c.ems_lng do
        label = "EMS — #{Stemi.Cases.Case.display_id(c)}"
        {:noreply, socket |> assign(:show_map, true) |> push_event("show_ems_map", %{lat: c.ems_lat, lng: c.ems_lng, label: label})}
      else
        {:noreply, put_flash(socket, :info, "No EMS location data yet.")}
      end
    end
  end

  @impl true
  def handle_event("ems_location_update", %{"case_id" => id, "lat" => lat, "lng" => lng}, socket) do
    case_record = Cases.get_case!(id)
    Cases.update_ems_location(case_record, lat, lng)
    {:noreply, socket}
  end

  # --- ER Actions ---
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
    {:noreply, socket |> put_flash(:info, "Forwarded to Cardiology!") |> assign(:selected_case, nil) |> assign(:cases, Cases.list_all_active_cases())}
  end

  @impl true
  def handle_event("reject_er", %{"id" => id}, socket) do
    user = socket.assigns.current_user
    case_record = Cases.get_case!(id)
    {:ok, _} = Cases.update_case_er(case_record, %{
      er_consultant_id: user.id,
      er_decision: "rejected",
      er_decided_at: DateTime.truncate(DateTime.utc_now(), :second),
      status: "er_rejected"
    })
    {:noreply, socket |> put_flash(:info, "Case rejected.") |> assign(:selected_case, nil) |> assign(:cases, Cases.list_all_active_cases())}
  end

  # --- Cardio Actions ---
  @impl true
  def handle_event("approve_cardio", %{"id" => id}, socket) do
    user = socket.assigns.current_user
    case_record = Cases.get_case!(id)
    {:ok, _} = Cases.update_case_cardiology(case_record, %{
      cardiologist_id: user.id,
      cardiology_decision: "approved",
      cardiology_decided_at: DateTime.truncate(DateTime.utc_now(), :second),
      status: "approved"
    })
    {:noreply, socket |> put_flash(:info, "Case approved!") |> assign(:selected_case, nil) |> assign(:cases, Cases.list_all_active_cases())}
  end

  @impl true
  def handle_event("reject_cardio", %{"id" => id}, socket) do
    user = socket.assigns.current_user
    case_record = Cases.get_case!(id)
    {:ok, _} = Cases.update_case_cardiology(case_record, %{
      cardiologist_id: user.id,
      cardiology_decision: "rejected",
      cardiology_decided_at: DateTime.truncate(DateTime.utc_now(), :second),
      status: "rejected"
    })
    {:noreply, socket |> put_flash(:info, "Case rejected.") |> assign(:selected_case, nil) |> assign(:cases, Cases.list_all_active_cases())}
  end

  # --- Eligibility Actions ---
  @impl true
  def handle_event("update_mrn", %{"value" => val}, socket) do
    {:noreply, assign(socket, :mrn_value, val)}
  end

  @impl true
  def handle_event("save_mrn", _params, socket) do
    user = socket.assigns.current_user
    case_record = Cases.get_case!(socket.assigns.selected_case.id)
    {:ok, _} = Cases.update_case_eligibility(case_record, %{
      eligibility_user_id: user.id,
      mrn_number: socket.assigns.mrn_value,
      eligibility_decided_at: DateTime.truncate(DateTime.utc_now(), :second)
    })
    {:noreply, socket |> put_flash(:info, "MRN assigned!") |> assign(:selected_case, nil) |> assign(:mrn_value, "") |> assign(:cases, Cases.list_all_active_cases())}
  end

  # --- EMS Actions ---
  @impl true
  def handle_event("dispatch", %{"id" => id}, socket) do
    user = socket.assigns.current_user
    case_record = Cases.get_case!(id)
    {:ok, _} = Cases.update_case_ems(case_record, %{
      ems_user_id: user.id,
      ems_dispatched_at: DateTime.truncate(DateTime.utc_now(), :second),
      status: "dispatched"
    })
    {:noreply, socket |> put_flash(:info, "EMS dispatched! GPS tracking started.") |> push_event("start_tracking", %{case_id: id}) |> assign(:selected_case, nil) |> assign(:cases, Cases.list_all_active_cases())}
  end

  # --- Cath Lab Actions ---
  @impl true
  def handle_event("set_preparing", _params, socket) do
    user = socket.assigns.current_user
    case_record = Cases.get_case!(socket.assigns.selected_case.id)
    {:ok, _} = Cases.update_case_cath_lab(case_record, %{cath_lab_user_id: user.id, cath_lab_status: "preparing"})
    {:noreply, socket |> put_flash(:info, "Cath Lab: Preparing!") |> assign(:selected_case, nil) |> assign(:cases, Cases.list_all_active_cases())}
  end

  @impl true
  def handle_event("set_ready", _params, socket) do
    user = socket.assigns.current_user
    case_record = Cases.get_case!(socket.assigns.selected_case.id)
    {:ok, _} = Cases.update_case_cath_lab(case_record, %{
      cath_lab_user_id: user.id,
      cath_lab_status: "ready",
      cath_lab_confirmed_at: DateTime.truncate(DateTime.utc_now(), :second)
    })
    {:noreply, socket |> put_flash(:info, "Cath Lab: Ready!") |> assign(:selected_case, nil) |> assign(:cases, Cases.list_all_active_cases())}
  end

  # --- Helpers ---

  defp filtered_cases(cases, "all"), do: cases
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
  defp status_label("er_approved"), do: "ER → Cardio"
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

  defp cath_label("pending"), do: "⏳ Pending"
  defp cath_label("preparing"), do: "🔧 Preparing"
  defp cath_label("ready"), do: "✓ Ready"
  defp cath_label(_), do: "—"

  defp cath_color("pending"), do: "#f59e0b"
  defp cath_color("preparing"), do: "#a855f7"
  defp cath_color("ready"), do: "#22c55e"
  defp cath_color(_), do: "#6b7280"

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

  defp format_datetime(nil), do: "—"
  defp format_datetime(dt), do: Calendar.strftime(dt, "%d %b %Y, %H:%M")

  defp count_by_status(cases, status), do: Enum.count(cases, &(&1.status == status))

  defp can_act?("er_consultant", c), do: c.status in ["pending_er", "pending_review"]
  defp can_act?("cardiologist", c), do: c.status == "er_approved" && is_nil(c.cardiology_decision)
  defp can_act?("eligibility", c), do: c.cardiology_decision == "approved"
  defp can_act?("ems", c), do: c.cardiology_decision == "approved" && c.status != "dispatched"
  defp can_act?("cath_lab", c), do: c.cardiology_decision == "approved"
  defp can_act?(_, _), do: false

  defp role_action_path("admin"), do: "/admin/users"
  defp role_action_path("phc"), do: "/phc/cases"
  defp role_action_path("er_consultant"), do: "/er/review"
  defp role_action_path("cardiologist"), do: "/cardio/review"
  defp role_action_path("eligibility"), do: "/elig/cases"
  defp role_action_path("ems"), do: "/ems/dispatch"
  defp role_action_path("cath_lab"), do: "/cath-lab/prepare"
  defp role_action_path(_), do: "/dashboard"

  defp role_action_label("admin"), do: "👤 Manage Users"
  defp role_action_label("phc"), do: "📋 Submit Cases"
  defp role_action_label("er_consultant"), do: "🏥 Review Cases"
  defp role_action_label("cardiologist"), do: "❤️ Cardio Review"
  defp role_action_label("eligibility"), do: "📁 Assign MRN"
  defp role_action_label("ems"), do: "🚑 Dispatch"
  defp role_action_label("cath_lab"), do: "🫀 Cath Lab"
  defp role_action_label(_), do: "Dashboard"

  @impl true
  def render(assigns) do
    ~H"""
    <style>
      .track-stats {
        display: grid;
        grid-template-columns: repeat(3, 1fr);
        gap: 8px;
        margin-bottom: 12px;
      }
      .track-stat {
        background: var(--bg-secondary);
        border-radius: 10px;
        padding: 10px;
        text-align: center;
        border: 1px solid var(--border);
      }
      .track-stat__num { font-size: 22px; font-weight: 800; line-height: 1; }
      .track-stat__label { font-size: 11px; color: var(--text-muted); margin-top: 4px; }
      .track-overlay {
        position: fixed; inset: 0; background: rgba(0,0,0,0.7);
        z-index: 1000; display: flex; align-items: flex-end; justify-content: center;
      }
      .track-panel {
        background: var(--bg-secondary, #1a1a2e);
        border-radius: 16px 16px 0 0;
        padding: 20px 20px 32px; width: 100%; max-width: 500px;
        max-height: 85vh; overflow-y: auto; position: relative; z-index: 1001;
      }
      .track-panel__handle { width: 40px; height: 4px; background: rgba(255,255,255,0.2); border-radius: 2px; margin: 0 auto 16px; }
      .track-panel__title { font-size: 18px; font-weight: 700; margin-bottom: 16px; }
      .tfield { display: flex; justify-content: space-between; align-items: center; padding: 10px 0; border-bottom: 1px solid var(--border, #333); }
      .tfield-label { font-size: 13px; color: var(--text-muted, #888); font-weight: 500; }
      .tfield-val { font-size: 14px; font-weight: 600; }
      .tphoto { padding: 10px 0; border-bottom: 1px solid var(--border, #333); }
      .tphoto .tfield-label { display: block; margin-bottom: 8px; }
      .tphoto img { width: 100%; border-radius: 8px; max-height: 250px; object-fit: contain; background: var(--bg-primary, #0f0f23); cursor: pointer; }
      .timeline-section { margin-top: 12px; padding-top: 12px; border-top: 1px solid var(--border, #333); }
      .timeline-title { font-size: 13px; color: var(--text-muted); font-weight: 600; margin-bottom: 8px; }
      .timeline-item { display: flex; align-items: center; gap: 8px; padding: 6px 0; }
      .timeline-dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; }
      .timeline-text { font-size: 13px; flex: 1; }
      .timeline-time { font-size: 11px; color: var(--text-muted); }
      .img-lightbox { position: fixed; inset: 0; background: rgba(0,0,0,0.92); z-index: 2000; display: flex; align-items: center; justify-content: center; cursor: pointer; }
      .img-lightbox img { max-width: 95vw; max-height: 90vh; object-fit: contain; border-radius: 8px; }
      .img-lightbox__close { position: absolute; top: 16px; right: 16px; background: rgba(255,255,255,0.1); border: none; color: white; width: 40px; height: 40px; border-radius: 50%; font-size: 20px; cursor: pointer; display: flex; align-items: center; justify-content: center; }
      .role-action-btn { display: block; margin-bottom: 12px; }
    </style>

    <!-- EMS GPS Tracker (hidden, for EMS users only) -->
    <div :if={@current_user.role == "ems"} id="ems-tracker-hook" phx-hook="EmsTracker" style="display:none;"></div>

    <div class="section-header">
      <div>
        <h1 class="section-header__title">📋 Track Cases</h1>
        <span class="section-header__count">{length(@cases)} active cases</span>
      </div>
      <a href={role_action_path(@current_user.role)} class="btn btn--primary btn--sm">
        {role_action_label(@current_user.role)}
      </a>
    </div>

    <!-- Stats Grid -->
    <div class="track-stats">
      <div class="track-stat">
        <div class="track-stat__num" style="color: #f59e0b;">{count_by_status(@cases, "pending_review") + count_by_status(@cases, "pending_er")}</div>
        <div class="track-stat__label">Pending ER</div>
      </div>
      <div class="track-stat">
        <div class="track-stat__num" style="color: #a855f7;">{count_by_status(@cases, "er_approved")}</div>
        <div class="track-stat__label">At Cardio</div>
      </div>
      <div class="track-stat">
        <div class="track-stat__num" style="color: #22c55e;">{count_by_status(@cases, "approved")}</div>
        <div class="track-stat__label">Approved</div>
      </div>
      <div class="track-stat">
        <div class="track-stat__num" style="color: #3b82f6;">{count_by_status(@cases, "dispatched")}</div>
        <div class="track-stat__label">Dispatched</div>
      </div>
      <div class="track-stat">
        <div class="track-stat__num" style="color: #ef4444;">{count_by_status(@cases, "rejected") + count_by_status(@cases, "er_rejected")}</div>
        <div class="track-stat__label">Rejected</div>
      </div>
      <div class="track-stat">
        <div class="track-stat__num" style="color: #10b981;">{count_by_status(@cases, "completed")}</div>
        <div class="track-stat__label">Completed</div>
      </div>
    </div>

    <!-- Filter Tabs -->
    <div class="tabs" id="status-tabs">
      <button
        class={"tab #{if @filter_status == "all", do: "tab--active"}"}
        phx-click="filter_status"
        phx-value-status="all"
      >All</button>
      <button
        :for={status <- ~w(pending_er er_approved approved dispatched rejected er_rejected)}
        class={"tab #{if @filter_status == status, do: "tab--active"}"}
        phx-click="filter_status"
        phx-value-status={status}
      >{status_label(status)}</button>
    </div>

    <!-- Case List -->
    <div class="user-list" id="track-cases-list">
      <div
        :for={c <- filtered_cases(@cases, @filter_status)}
        class="user-card"
        style={"cursor: pointer; border-left: 4px solid #{status_color(c.status)};"}
        phx-click="view_case"
        phx-value-id={c.id}
        id={"track-case-#{c.id}"}
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
            <span :if={c.phc_user} class="badge badge--phc">From: {c.phc_user.full_name}</span>
            <span style="color: var(--text-muted); font-size: 12px;">{time_ago(c.inserted_at)}</span>
          </div>
        </div>
        <a :if={c.phc_hospital && c.phc_hospital.map_url} href={c.phc_hospital.map_url} target="_blank" rel="noopener" style="font-size: 20px; text-decoration: none; flex-shrink: 0;" title={"Navigate to #{c.phc_hospital.name}"} onclick="event.stopPropagation();">📍</a>
      </div>

      <div :if={filtered_cases(@cases, @filter_status) == []} class="empty-state">
        <div class="empty-state__icon">📋</div>
        <div class="empty-state__text">No cases matching this filter.</div>
      </div>
    </div>

    <!-- Sign Out -->
    <div style="margin-top: 24px;">
      
        
        <a href="/logout" class="btn btn--ghost btn--full" id="btn-logout">Sign Out</a>
      
    </div>

    <!-- Case Detail Modal -->
    <div :if={@selected_case} class="track-overlay" id="track-case-detail-modal">
      <div class="track-panel">
        <div class="track-panel__handle"></div>
        <h2 class="track-panel__title">{Case.display_id(@selected_case)}</h2>

        <div class="tfield">
          <span class="tfield-label">Patient ID</span>
          <span class="tfield-val">{@selected_case.patient_id}</span>
        </div>

        <div class="tfield">
          <span class="tfield-label">Status</span>
          <span class="tfield-val" style={"color: #{status_color(@selected_case.status)}"}>{status_label(@selected_case.status)}</span>
        </div>

        <div :if={@selected_case.mrn_number && @selected_case.mrn_number != ""} class="tfield">
          <span class="tfield-label">MRN</span>
          <span class="tfield-val" style="color: #f59e0b;">{@selected_case.mrn_number}</span>
        </div>

        <div :if={@selected_case.phc_user} class="tfield">
          <span class="tfield-label">Submitted By</span>
          <span class="tfield-val">{@selected_case.phc_user.full_name}</span>
        </div>

        <div :if={@selected_case.phc_hospital} class="tfield">
          <span class="tfield-label">From Facility</span>
          <span class="tfield-val">{@selected_case.phc_hospital.name}</span>
        </div>

        <div class="tfield">
          <span class="tfield-label">Cath Lab</span>
          <span class="tfield-val" style={"color: #{cath_color(@selected_case.cath_lab_status)}"}>{cath_label(@selected_case.cath_lab_status)}</span>
        </div>

        <!-- ECG Image -->
        <div :if={@selected_case.ecg_photo_url && @selected_case.ecg_photo_url != "no_photo"} class="tphoto">
          <span class="tfield-label">ECG Photo (tap to enlarge)</span>
          <img src={@selected_case.ecg_photo_url} alt="ECG" phx-click="preview_image" phx-value-url={@selected_case.ecg_photo_url} />
        </div>

        <!-- ID Image -->
        <div :if={@selected_case.id_photo_url} class="tphoto">
          <span class="tfield-label">Patient ID Photo (tap to enlarge)</span>
          <img src={@selected_case.id_photo_url} alt="Patient ID" phx-click="preview_image" phx-value-url={@selected_case.id_photo_url} />
        </div>

        <!-- Timeline -->
        <div class="timeline-section">
          <div class="timeline-title">Case Timeline</div>

          <div class="timeline-item">
            <div class="timeline-dot" style="background: #22c55e;"></div>
            <span class="timeline-text">Created by {if @selected_case.phc_user, do: @selected_case.phc_user.full_name, else: "?"}</span>
            <span class="timeline-time">{format_datetime(@selected_case.inserted_at)}</span>
          </div>

          <div :if={@selected_case.er_consultant} class="timeline-item">
            <div class="timeline-dot" style={"background: #{if @selected_case.er_decision == "approved", do: "#a855f7", else: "#ef4444"};"}></div>
            <span class="timeline-text">
              ER: {if @selected_case.er_decision == "approved", do: "Forwarded", else: "Rejected"} by {@selected_case.er_consultant.full_name}
            </span>
            <span class="timeline-time">{format_datetime(@selected_case.er_decided_at)}</span>
          </div>

          <div :if={@selected_case.cardiologist} class="timeline-item">
            <div class="timeline-dot" style={"background: #{if @selected_case.cardiology_decision == "approved", do: "#22c55e", else: "#ef4444"};"}></div>
            <span class="timeline-text">
              Cardio: {if @selected_case.cardiology_decision == "approved", do: "Approved", else: "Rejected"} by {@selected_case.cardiologist.full_name}
            </span>
            <span class="timeline-time">{format_datetime(@selected_case.cardiology_decided_at)}</span>
          </div>

          <div :if={@selected_case.eligibility} class="timeline-item">
            <div class="timeline-dot" style="background: #f59e0b;"></div>
            <span class="timeline-text">
              MRN: {@selected_case.mrn_number || "—"} by {@selected_case.eligibility.full_name}
            </span>
            <span class="timeline-time">{format_datetime(@selected_case.eligibility_decided_at)}</span>
          </div>

          <div :if={@selected_case.cath_lab_user} class="timeline-item">
            <div class="timeline-dot" style={"background: #{cath_color(@selected_case.cath_lab_status)};"}></div>
            <span class="timeline-text">
              Cath Lab: {cath_label(@selected_case.cath_lab_status)} by {@selected_case.cath_lab_user.full_name}
            </span>
            <span class="timeline-time">{format_datetime(@selected_case.cath_lab_confirmed_at)}</span>
          </div>

          <div :if={@selected_case.ems_user} class="timeline-item">
            <div class="timeline-dot" style="background: #3b82f6;"></div>
            <span class="timeline-text">
              Dispatched by {@selected_case.ems_user.full_name}
            </span>
            <span class="timeline-time">{format_datetime(@selected_case.ems_dispatched_at)}</span>
          </div>
        </div>

        <!-- Map Link -->
        <div :if={@selected_case.phc_hospital && @selected_case.phc_hospital.map_url} style="margin-top: 12px;">
          <a href={@selected_case.phc_hospital.map_url} target="_blank" rel="noopener" class="btn btn--full" style="background: #10b981; color: white; text-align: center; display: flex; align-items: center; justify-content: center; gap: 8px; font-weight: 600;">
            📍 Navigate to {@selected_case.phc_hospital.name}
          </a>
        </div>

        <!-- EMS Live Tracking -->
        <div :if={@selected_case.status == "dispatched"} style="margin-top: 12px;" id="ems-map-hook" phx-hook="EmsMap">
          <button type="button" class="btn btn--full" style={"background: #{if @show_map, do: "#6b7280", else: "#3b82f6"}; color: white; display: flex; align-items: center; justify-content: center; gap: 8px; font-weight: 600;"} phx-click="toggle_map">
            {if @show_map, do: "✕ Close Map", else: "🚑 Track EMS Live"}
          </button>
          <div id="ems-map-container" style={"margin-top: 8px; border-radius: 12px; overflow: hidden; #{if !@show_map, do: "display:none;"}"}></div>
        </div>

        <!-- Role-Based Actions -->
        <!-- ER Consultant: Forward/Reject when pending -->
        <div :if={@current_user.role == "er_consultant" && @selected_case.status in ["pending_er", "pending_review"]} style="display: flex; gap: 8px; margin-top: 16px;">
          <button type="button" class="btn btn--ghost" style="flex:1; border-color: #ef4444; color: #ef4444;" phx-click="reject_er" phx-value-id={@selected_case.id}>✕ Reject</button>
          <button type="button" class="btn btn--primary" style="flex:2; background: #a855f7;" phx-click="forward_to_cardio" phx-value-id={@selected_case.id}>✓ Forward to Cardio</button>
        </div>

        <!-- Cardiologist: Approve/Reject when er_approved -->
        <div :if={@current_user.role == "cardiologist" && @selected_case.status == "er_approved" && is_nil(@selected_case.cardiology_decision)} style="display: flex; gap: 8px; margin-top: 16px;">
          <button type="button" class="btn btn--ghost" style="flex:1; border-color: #ef4444; color: #ef4444;" phx-click="reject_cardio" phx-value-id={@selected_case.id}>✕ Reject</button>
          <button type="button" class="btn btn--primary" style="flex:2; background: #22c55e;" phx-click="approve_cardio" phx-value-id={@selected_case.id}>✓ Approve</button>
        </div>

        <!-- Eligibility: MRN Input when approved -->
        <div :if={@current_user.role == "eligibility" && @selected_case.cardiology_decision == "approved"} style="margin-top: 16px;">
          <div class="form-group">
            <label class="form-label" for="dash_mrn">Medical Record Number (MRN)</label>
            <input class="form-input" type="text" id="dash_mrn" value={@mrn_value} placeholder="Enter MRN" autocomplete="off" phx-keyup="update_mrn" />
          </div>
          <div style="display: flex; gap: 8px; margin-top: 8px;">
            <button type="button" class="btn btn--ghost" style="flex:1" phx-click="close_case">Cancel</button>
            <button type="button" class="btn btn--primary" style="flex:2; background: #f59e0b;" phx-click="save_mrn">{if @selected_case.mrn_number && @selected_case.mrn_number != "", do: "Update MRN", else: "Assign MRN"}</button>
          </div>
        </div>

        <!-- EMS: Dispatch when approved and not dispatched -->
        <div :if={@current_user.role == "ems" && @selected_case.cardiology_decision == "approved" && @selected_case.status != "dispatched"} style="display: flex; gap: 8px; margin-top: 16px;">
          <button type="button" class="btn btn--ghost" style="flex:1" phx-click="close_case">Cancel</button>
          <button type="button" class="btn btn--primary" style="flex:2; background: #3b82f6;" phx-click="dispatch" phx-value-id={@selected_case.id}>🚑 Dispatch EMS</button>
        </div>

        <!-- Cath Lab: Preparing / Ready -->
        <div :if={@current_user.role == "cath_lab" && @selected_case.cardiology_decision == "approved"} style="display: flex; gap: 8px; margin-top: 16px;">
          <button type="button" class="btn btn--ghost" style="flex:1" phx-click="close_case">Cancel</button>
          <button :if={@selected_case.cath_lab_status == "pending"} type="button" class="btn btn--primary" style="flex:2; background: #a855f7;" phx-click="set_preparing">🔧 Start Preparing</button>
          <button :if={@selected_case.cath_lab_status == "preparing"} type="button" class="btn btn--primary" style="flex:2; background: #22c55e;" phx-click="set_ready">✓ Mark Ready</button>
          <div :if={@selected_case.cath_lab_status == "ready"} style="flex:2; text-align: center; padding: 12px; color: #22c55e; font-weight: 700;">✓ Cath Lab Ready</div>
        </div>

        <!-- Default Close (for roles without actions or already actioned) -->
        <div :if={@current_user.role not in ["er_consultant", "cardiologist", "eligibility", "ems", "cath_lab"] or not can_act?(@current_user.role, @selected_case)} style="margin-top: 16px;">
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
