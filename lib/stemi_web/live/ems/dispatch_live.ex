defmodule StemiWeb.Ems.DispatchLive do
  use StemiWeb, :live_view

  alias Stemi.Cases
  alias Stemi.Cases.Case
  import StemiWeb.Components.StatsGrid

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Cases.subscribe()

    cases = Cases.list_ready_for_dispatch_for_list()

    socket =
      socket
      |> assign(:page_title, "EMS Dispatch")
      |> assign(:active_tab, :dashboard)
      |> assign(:cases, cases)
      |> assign(:selected_case, nil)
      |> assign(:preview_image, nil)
      |> assign(:stats, Cases.case_stats())
      |> assign(:show_map, false)
      |> assign(:tracking_case_id, nil)

    {:ok, socket}
  end

  # Real-time update from PubSub
  @impl true
  def handle_info({event, _payload}, socket) when event in [:case_cardiology_updated, :case_ems_dispatched] do
    cases = Cases.list_ready_for_dispatch_for_list()

    socket =
      socket
      |> assign(:cases, cases)
      |> assign(:stats, Cases.case_stats())
      |> push_event("play-alert", %{})

    {:noreply, socket}
  end

  # EMS location update — push to map in real-time
  @impl true
  def handle_info({:ems_location_updated, case_data}, socket) do
    if socket.assigns.show_map && socket.assigns.selected_case && socket.assigns.selected_case.id == case_data.id do
      {:noreply, push_event(socket, "update_ems_position", %{lat: case_data.ems_lat, lng: case_data.ems_lng})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:comment_added, comment}, socket) do
    case socket.assigns.selected_case do
      %{id: id} when id == comment.case_id ->
        Phoenix.LiveView.send_update(StemiWeb.Components.CaseComments,
          id: "comments-#{id}",
          comments_tree: Cases.list_comments_tree(id)
        )
      _ -> :ok
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
    {:noreply, socket |> assign(:selected_case, nil) |> assign(:show_map, false)}
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
  def handle_event("ems_location_update", %{"case_id" => id, "lat" => lat, "lng" => lng}, socket) do
    case_record = Cases.get_case!(id)
    Cases.update_ems_location(case_record, lat, lng)
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_map", _params, socket) do
    c = socket.assigns.selected_case
    if socket.assigns.show_map do
      {:noreply, socket |> assign(:show_map, false) |> push_event("hide_ems_map", %{})}
    else
      label = "EMS — #{Stemi.Cases.Case.display_id(c)}"
      phc = c && c.phc_hospital
      payload = %{
        lat: c && c.ems_lat,
        lng: c && c.ems_lng,
        label: label,
        phc_lat: phc && phc.lat,
        phc_lng: phc && phc.lng,
        phc_name: phc && phc.name
      }

      if c && c.ems_lat && c.ems_lng do
        {:noreply, socket |> assign(:show_map, true) |> push_event("show_ems_map", payload)}
      else
        # Open map anyway showing PHC → KFMC route even if no live GPS yet
        {:noreply, socket |> assign(:show_map, true) |> push_event("show_ems_map", payload)}
      end
    end
  end

  @impl true
  def handle_event("dispatch", %{"id" => id}, socket) do
    user = socket.assigns.current_user
    case_record = Cases.get_case!(id)

    {:ok, _} = Cases.update_case_ems(case_record, %{
      ems_user_id: user.id,
      ems_dispatched_at: DateTime.truncate(DateTime.utc_now(), :second),
      status: "dispatched"
    })

    cases = Cases.list_ready_for_dispatch_for_list()
    # Re-fetch so selected_case reflects status: "dispatched" (required for EmsMap hook to mount)
    dispatched = Cases.get_case!(id)
    phc = dispatched.phc_hospital

    map_payload = %{
      lat: nil,
      lng: nil,
      label: "EMS — #{Cases.Case.display_id(dispatched)}",
      phc_lat: phc && phc.lat,
      phc_lng: phc && phc.lng,
      phc_name: phc && phc.name
    }

    socket =
      socket
      |> put_flash(:info, "EMS dispatched! Navigating to patient.")
      |> push_event("start_tracking", %{case_id: id})
      |> push_event("show_ems_map", map_payload)
      |> assign(:cases, cases)
      |> assign(:selected_case, dispatched)
      |> assign(:show_map, true)
      |> assign(:tracking_case_id, id)

    {:noreply, socket}
  end

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

  @impl true
  def render(assigns) do
    ~H"""
    <style>
      .ems-overlay {
        position: fixed;
        inset: 0;
        background: rgba(0,0,0,0.7);
        z-index: 1000;
        display: flex;
        align-items: flex-end;
        justify-content: center;
      }
      .ems-panel {
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
      .ems-panel__handle {
        width: 40px;
        height: 4px;
        background: rgba(255,255,255,0.2);
        border-radius: 2px;
        margin: 0 auto 16px;
      }
      .ems-panel__title {
        font-size: 18px;
        font-weight: 700;
        margin-bottom: 16px;
      }
      .ems-field {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 10px 0;
        border-bottom: 1px solid var(--border, #333);
      }
      .ems-label { font-size: 13px; color: var(--text-muted, #888); font-weight: 500; }
      .ems-val { font-size: 15px; font-weight: 600; }
      .ems-btns { display: flex; gap: 8px; margin-top: 16px; }
      .ems-photo { padding: 10px 0; border-bottom: 1px solid var(--border, #333); }
      .ems-photo .ems-label { display: block; margin-bottom: 8px; }
      .ems-photo img { width: 100%; border-radius: 8px; max-height: 250px; object-fit: contain; background: var(--bg-primary, #0f0f23); cursor: pointer; }
      .img-lightbox { position: fixed; inset: 0; background: rgba(0,0,0,0.92); z-index: 2000; display: flex; align-items: center; justify-content: center; cursor: pointer; }
      .img-lightbox img { max-width: 95vw; max-height: 90vh; object-fit: contain; border-radius: 8px; }
      .img-lightbox__close { position: absolute; top: 16px; right: 16px; background: rgba(255,255,255,0.1); border: none; color: white; width: 40px; height: 40px; border-radius: 50%; font-size: 20px; cursor: pointer; display: flex; align-items: center; justify-content: center; }
    </style>

    <!-- EMS GPS Tracker (always present for GPS sharing) -->
    <div id="ems-tracker-hook" phx-hook="EmsTracker" style="display:none;"></div>

    <div class="section-header">
      <div>
        <h1 class="section-header__title">EMS Dispatch</h1>
        <span class="section-header__count">{Enum.count(@cases, & &1.status != "dispatched")} ready · {length(@cases)} total</span>
      </div>
    </div>

    <.stats_grid stats={@stats} />

    <!-- Case List -->
    <div class="user-list" id="dispatch-list">
      <div
        :for={c <- @cases}
        class="case-card"
        style={"--card-accent: #{if c.status == "dispatched", do: "#22c55e", else: "#3b82f6"}"}
        phx-click="view_case"
        phx-value-id={c.id}
        id={"dispatch-#{c.id}"}
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
            <div class="case-card__sublabel">Cath Lab</div>
          </div>
        </div>
        <div class="case-card__footer">
          <span class="badge" style="background: #22c55e22; color: #22c55e;">MRN: {c.mrn_number}</span>
          <span :if={c.status == "dispatched"} class="badge" style="background: #22c55e22; color: #22c55e;">✓ Dispatched</span>
          <span :if={c.status != "dispatched"} style="color: #3b82f6; font-weight: 600; margin-left: auto;">DISPATCH →</span>
          <span :if={c.status == "dispatched"} style="color: #22c55e; font-weight: 600; margin-left: auto;">✓ DONE</span>
        </div>
      </div>

      <div :if={@cases == []} class="empty-state">
        <div class="empty-state__icon">🚑</div>
        <div class="empty-state__text">No cases ready for dispatch.</div>
      </div>
    </div>

    <!-- Sign Out -->
    <div style="margin-top: 24px;">
      
        
        <a href="/logout" class="btn btn--ghost btn--full" id="btn-logout">Sign Out</a>
      
    </div>

    <!-- Case Detail Modal -->
    <div :if={@selected_case} class="ems-overlay" id="dispatch-detail-modal">
      <div class="ems-panel">
        <div class="ems-panel__handle"></div>
        <h2 class="ems-panel__title">{Case.display_id(@selected_case)}</h2>

        <div class="ems-field">
          <span class="ems-label">Patient ID</span>
          <span class="ems-val">{@selected_case.patient_id}</span>
        </div>

        <div class="ems-field">
          <span class="ems-label">MRN</span>
          <span class="ems-val" style="color: var(--success); font-weight: 700;">{@selected_case.mrn_number}</span>
        </div>

        <div class="ems-field">
          <span class="ems-label">PHC Source</span>
          <span class="ems-val">{@selected_case.phc_user.full_name}</span>
        </div>

        <div :if={@selected_case.phc_hospital} class="ems-field">
          <span class="ems-label">PHC Facility</span>
          <span class="ems-val" style="font-size: 13px;">{@selected_case.phc_hospital.name}</span>
        </div>

        <div :if={@selected_case.phc_hospital && @selected_case.phc_hospital.map_url} style="padding: 8px 0;">
          <a
            href={@selected_case.phc_hospital.map_url}
            target="_blank"
            rel="noopener"
            class="btn btn--full"
            style="background: #10b981; color: white; text-align: center; display: flex; align-items: center; justify-content: center; gap: 8px; font-weight: 600;"
          >
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/>
              <circle cx="12" cy="10" r="3"/>
            </svg>
            Navigate to PHC
          </a>
        </div>

        <div :if={@selected_case.er_consultant} class="ems-field">
          <span class="ems-label">ER Consultant</span>
          <span class="ems-val" style="color: #22c55e;">✓ {@selected_case.er_consultant.full_name}</span>
        </div>

        <div :if={@selected_case.cardiologist} class="ems-field">
          <span class="ems-label">Cardiologist</span>
          <span class="ems-val" style="color: #22c55e;">✓ {@selected_case.cardiologist.full_name}</span>
        </div>

        <div :if={@selected_case.eligibility} class="ems-field">
          <span class="ems-label">Eligibility</span>
          <span class="ems-val" style="color: #22c55e;">✓ {@selected_case.eligibility.full_name}</span>
        </div>

        <div class="ems-field">
          <span class="ems-label">Submitted</span>
          <span class="ems-val">{time_ago(@selected_case.inserted_at)}</span>
        </div>

        <!-- ECG Image -->
        <div :if={@selected_case.ecg_photo_url && @selected_case.ecg_photo_url != "no_photo"} class="ems-photo">
          <span class="ems-label">ECG Photo (tap to enlarge)</span>
          <img src={@selected_case.ecg_photo_url} alt="ECG" phx-click="preview_image" phx-value-url={@selected_case.ecg_photo_url} />
        </div>

        <!-- ID Image -->
        <div :if={@selected_case.id_photo_url} class="ems-photo">
          <span class="ems-label">Patient ID Photo (tap to enlarge)</span>
          <img src={@selected_case.id_photo_url} alt="Patient ID" phx-click="preview_image" phx-value-url={@selected_case.id_photo_url} />
        </div>

        <!-- Timeline -->
        <div style="margin-top: 12px; padding-top: 12px; border-top: 1px solid var(--border, #333);">
          <div style="font-size: 13px; color: var(--text-muted); font-weight: 600; margin-bottom: 8px;">Timeline</div>
          <div style="display: flex; align-items: center; gap: 8px; padding: 6px 0;">
            <div style="width: 8px; height: 8px; border-radius: 50%; background: #22c55e; flex-shrink: 0;"></div>
            <span style="font-size: 13px; flex: 1;">Created</span>
            <span style="font-size: 11px; color: var(--text-muted);">{format_datetime(@selected_case.inserted_at)}</span>
          </div>
          <div :if={@selected_case.er_decided_at} style="display: flex; align-items: center; gap: 8px; padding: 6px 0;">
            <div style="width: 8px; height: 8px; border-radius: 50%; background: #a855f7; flex-shrink: 0;"></div>
            <span style="font-size: 13px; flex: 1;">ER Forwarded</span>
            <span style="font-size: 11px; color: var(--text-muted);">{format_datetime(@selected_case.er_decided_at)}</span>
          </div>
          <div :if={@selected_case.cardiology_decided_at} style="display: flex; align-items: center; gap: 8px; padding: 6px 0;">
            <div style="width: 8px; height: 8px; border-radius: 50%; background: #22c55e; flex-shrink: 0;"></div>
            <span style="font-size: 13px; flex: 1;">Cardio Approved</span>
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

        <!-- Comments -->
        <div style="margin-top: 12px; padding-top: 12px; border-top: 1px solid var(--border, #333);">
          <.live_component
            module={StemiWeb.Components.CaseComments}
            id={"comments-#{@selected_case.id}"}
            case_id={@selected_case.id}
            current_user={@current_user}
          />
        </div>

        <div :if={@selected_case.status != "dispatched"} class="ems-btns">
          <button type="button" class="btn btn--ghost" style="flex:1" phx-click="close_case">Cancel</button>
          <button
            type="button"
            class="btn btn--primary"
            style="flex:2; background: #3b82f6;"
            phx-click="dispatch"
            phx-value-id={@selected_case.id}
          >
            🚑 Dispatch EMS
          </button>
        </div>

        <div :if={@selected_case.status == "dispatched" && @selected_case.phc_hospital && @selected_case.phc_hospital.map_url} style="margin-top: 8px;">
          <a
            href={@selected_case.phc_hospital.map_url}
            target="_blank"
            rel="noopener"
            class="btn btn--full"
            style="background: #10b981; color: white; text-align: center; display: flex; align-items: center; justify-content: center; gap: 8px; font-weight: 600;"
          >
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
              <path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/>
              <circle cx="12" cy="10" r="3"/>
            </svg>
            Navigate to PHC
          </a>
        </div>

        <!-- EMS Live Map (for dispatched cases) -->
        <div :if={@selected_case.status == "dispatched"} style="margin-top: 8px;" id="ems-map-hook" phx-hook="EmsMap">
          <button type="button" class="btn btn--full" style={"background: #{if @show_map, do: "#6b7280", else: "#3b82f6"}; color: white; display: flex; align-items: center; justify-content: center; gap: 8px; font-weight: 600;"} phx-click="toggle_map">
            {if @show_map, do: "✕ Close Map", else: "🚑 Track EMS Live"}
          </button>
          <div id="ems-map-container" style={"margin-top: 8px; border-radius: 12px; overflow: hidden; #{if !@show_map, do: "display:none;"}"}></div>
        </div>

        <div :if={@selected_case.status == "dispatched"} style="margin-top: 16px;">
          <div style="text-align: center; color: #22c55e; font-weight: 700; margin-bottom: 12px;">✓ Already Dispatched</div>
          <button type="button" class="btn btn--ghost btn--full" phx-click="close_case">Close</button>
        </div>
      </div>
    </div>

    <!-- Fullscreen Image Preview -->
    <div :if={@preview_image} class="img-lightbox" phx-click="close_preview" id="ems-img-lightbox">
      <button class="img-lightbox__close" phx-click="close_preview">✕</button>
      <img src={@preview_image} alt="Preview" />
    </div>
    """
  end
end
