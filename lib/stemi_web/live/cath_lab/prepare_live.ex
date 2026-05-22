defmodule StemiWeb.CathLab.PrepareLive do
  use StemiWeb, :live_view

  alias Stemi.Cases
  alias Stemi.Cases.Case
  import StemiWeb.Components.StatsGrid
  use StemiWeb.EmsMapHelpers

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Cases.subscribe()

    cases = Cases.list_cath_lab_cases()

    socket =
      socket
      |> assign(:page_title, "Cath Lab")
      |> assign(:active_tab, :dashboard)
      |> assign(:cases, cases)
      |> assign(:selected_case, nil)
      |> assign(:preview_image, nil)
      |> assign(:stats, Cases.case_stats())
      |> assign(:show_map, false)

    {:ok, socket}
  end

  @impl true
  def handle_info({event, _payload}, socket) when event in [:case_created, :case_er_updated, :case_cardiology_updated, :case_eligibility_updated, :case_ems_dispatched, :case_cath_lab_updated] do
    cases = Cases.list_cath_lab_cases()

    socket =
      socket
      |> assign(:cases, cases)
      |> assign(:stats, Cases.case_stats())
      |> push_event("play-alert", %{})

    {:noreply, socket}
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
  def handle_event("set_preparing", _params, socket) do
    case_record = Cases.get_case!(socket.assigns.selected_case.id)
    user = socket.assigns.current_user

    result = Cases.update_case_cath_lab(case_record, %{
      cath_lab_user_id: user.id,
      cath_lab_status: "preparing"
    })

    case result do
      {:ok, _} ->
        cases = Cases.list_cath_lab_cases()
        socket =
          socket
          |> put_flash(:info, "Cath Lab: Preparing!")
          |> assign(:cases, cases)
          |> assign(:selected_case, nil)
        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update")}
    end
  end

  @impl true
  def handle_event("set_ready", _params, socket) do
    case_record = Cases.get_case!(socket.assigns.selected_case.id)
    user = socket.assigns.current_user

    result = Cases.update_case_cath_lab(case_record, %{
      cath_lab_user_id: user.id,
      cath_lab_status: "ready",
      cath_lab_confirmed_at: DateTime.truncate(DateTime.utc_now(), :second)
    })

    case result do
      {:ok, _} ->
        cases = Cases.list_cath_lab_cases()
        socket =
          socket
          |> put_flash(:info, "Cath Lab: Ready for patient!")
          |> assign(:cases, cases)
          |> assign(:selected_case, nil)
        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update")}
    end
  end

  defp cath_status_color("pending"), do: "#f59e0b"
  defp cath_status_color("preparing"), do: "#a855f7"
  defp cath_status_color("ready"), do: "#22c55e"
  defp cath_status_color(_), do: "#6b7280"

  defp cath_status_label("pending"), do: "Pending"
  defp cath_status_label("preparing"), do: "Preparing"
  defp cath_status_label("ready"), do: "Ready ✓"
  defp cath_status_label(_), do: "Unknown"

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

  @impl true
  def render(assigns) do
    ~H"""
    <style>
      .cath-overlay {
        position: fixed;
        inset: 0;
        background: rgba(0,0,0,0.7);
        z-index: 1000;
        display: flex;
        align-items: flex-end;
        justify-content: center;
      }
      .cath-panel {
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
      .cath-panel__handle {
        width: 40px;
        height: 4px;
        background: rgba(255,255,255,0.2);
        border-radius: 2px;
        margin: 0 auto 16px;
      }
      .cath-panel__title {
        font-size: 18px;
        font-weight: 700;
        margin-bottom: 16px;
      }
      .cath-field {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 10px 0;
        border-bottom: 1px solid var(--border, #333);
      }
      .cath-label { font-size: 13px; color: var(--text-muted, #888); font-weight: 500; }
      .cath-val { font-size: 15px; font-weight: 600; }
      .cath-photo { padding: 10px 0; border-bottom: 1px solid var(--border, #333); }
      .cath-photo .cath-label { display: block; margin-bottom: 10px; }
      .cath-photo img {
        width: 100%;
        border-radius: 8px;
        max-height: 250px;
        object-fit: contain;
        background: var(--bg-primary, #0f0f23);
        cursor: pointer;
      }
      .cath-btns {
        display: flex;
        gap: 8px;
        margin-top: 16px;
      }
      .img-lightbox { position: fixed; inset: 0; background: rgba(0,0,0,0.92); z-index: 2000; display: flex; align-items: center; justify-content: center; cursor: pointer; }
      .img-lightbox img { max-width: 95vw; max-height: 90vh; object-fit: contain; border-radius: 8px; }
      .img-lightbox__close { position: absolute; top: 16px; right: 16px; background: rgba(255,255,255,0.1); border: none; color: white; width: 40px; height: 40px; border-radius: 50%; font-size: 20px; cursor: pointer; display: flex; align-items: center; justify-content: center; }
    </style>

    <div class="section-header">
      <div>
        <h1 class="section-header__title">🫀 Cath Lab</h1>
        <span class="section-header__count">{length(@cases)} cases</span>
      </div>
      <a href="/dashboard" class="btn btn--ghost btn--sm">📋 Track All</a>
    </div>

    <.stats_grid stats={@stats} />

    <!-- Case List -->
    <div class="user-list" id="cath-list">
      <div
        :for={c <- @cases}
        class="case-card"
        style={"--card-accent: #{cath_status_color(c.cath_lab_status)}"}
        phx-click="view_case"
        phx-value-id={c.id}
        id={"cath-#{c.id}"}
      >
        <div class="case-card__header">
          <span class="case-card__id">{Case.display_id(c)}</span>
          <span class="case-card__time">{time_ago(c.inserted_at)}</span>
        </div>
        <div class="case-card__route">
          <div class="case-card__origin">
            <div class="case-card__code">PHC</div>
            <div class="case-card__sublabel">{if c.phc_hospital, do: c.phc_hospital.name, else: "Facility"}</div>
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
          <span class="badge" style={"background: #{cath_status_color(c.cath_lab_status)}22; color: #{cath_status_color(c.cath_lab_status)};"}>
            {cath_status_label(c.cath_lab_status)}
          </span>
          <span :if={c.patient_id && c.patient_id != ""} style="color: var(--text-secondary);">👤 {c.patient_id}</span>
          <span style={"color: #{cath_status_color(c.cath_lab_status)}; font-weight: 600; margin-left: auto;"}>{cath_status_label(c.cath_lab_status)}</span>
        </div>
      </div>

      <div :if={@cases == []} class="empty-state">
        <div class="empty-state__icon">🫀</div>
        <div class="empty-state__text">No cases awaiting Cath Lab preparation.</div>
      </div>
    </div>

    <!-- Sign Out -->
    <div style="margin-top: 24px;">
      
        
        <a href="/logout" class="btn btn--ghost btn--full" id="btn-logout">Sign Out</a>
      
    </div>

    <!-- Case Detail Modal -->
    <div :if={@selected_case} class="cath-overlay" id="cath-detail-modal">
      <div class="cath-panel">
        <div class="cath-panel__handle"></div>
        <h2 class="cath-panel__title">Cath Lab Preparation</h2>

        <div class="cath-field">
          <span class="cath-label">Case</span>
          <span class="cath-val">{Case.display_id(@selected_case)}</span>
        </div>

        <div class="cath-field">
          <span class="cath-label">Patient ID</span>
          <span class="cath-val">{@selected_case.patient_id}</span>
        </div>

        <div :if={@selected_case.phc_user} class="cath-field">
          <span class="cath-label">Submitted By</span>
          <span class="cath-val">{@selected_case.phc_user.full_name}</span>
        </div>

        <div :if={@selected_case.phc_hospital} class="cath-field">
          <span class="cath-label">From Facility</span>
          <span class="cath-val">{@selected_case.phc_hospital.name}</span>
        </div>

        <div class="cath-field">
          <span class="cath-label">Cath Lab Status</span>
          <span class="cath-val" style={"color: #{cath_status_color(@selected_case.cath_lab_status)}"}>{cath_status_label(@selected_case.cath_lab_status)}</span>
        </div>

        <!-- ECG Image -->
        <div :if={@selected_case.ecg_photo_url && @selected_case.ecg_photo_url != "no_photo"} class="cath-photo">
          <span class="cath-label">ECG Photo (tap to enlarge)</span>
          <img src={@selected_case.ecg_photo_url} alt="ECG" phx-click="preview_image" phx-value-url={@selected_case.ecg_photo_url} />
        </div>

        <!-- ID Photo -->
        <div :if={@selected_case.id_photo_url} class="cath-photo">
          <span class="cath-label">Patient ID Photo (tap to enlarge)</span>
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

        <!-- Action Buttons -->
        <div class="cath-btns">
          <button type="button" class="btn btn--ghost" style="flex:1" phx-click="close_case">Cancel</button>
          <button
            :if={@selected_case.cath_lab_status == "pending"}
            type="button"
            class="btn btn--primary"
            style="flex:2; background: #a855f7;"
            phx-click="set_preparing"
          >
            🔧 Start Preparing
          </button>
          <button
            :if={@selected_case.cath_lab_status == "preparing"}
            type="button"
            class="btn btn--primary"
            style="flex:2; background: #22c55e;"
            phx-click="set_ready"
          >
            ✓ Mark Ready
          </button>
          <div
            :if={@selected_case.cath_lab_status == "ready"}
            style="flex:2; text-align: center; padding: 12px; color: #22c55e; font-weight: 700; font-size: 16px;"
          >
            ✓ Cath Lab Ready
          </div>
        </div>

        <!-- EMS Live Tracking -->
        <div :if={@selected_case.status == "dispatched"} style="margin-top: 12px;" id="ems-map-hook" phx-hook="EmsMap">
          <button type="button" class="btn btn--full" style={"background: #{if @show_map, do: "#6b7280", else: "#3b82f6"}; color: white; display: flex; align-items: center; justify-content: center; gap: 8px; font-weight: 600;"} phx-click="toggle_map">
            {if @show_map, do: "✕ Close Map", else: "🚑 Track EMS Live"}
          </button>
          <div id="ems-map-container" style={"margin-top: 8px; border-radius: 12px; overflow: hidden; #{if !@show_map, do: "display:none;"}"}></div>
        </div>

      </div>
    </div>

    <!-- Fullscreen Image Preview -->
    <div :if={@preview_image} class="img-lightbox" phx-click="close_preview" id="cath-img-lightbox">
      <button class="img-lightbox__close" phx-click="close_preview">✕</button>
      <img src={@preview_image} alt="Preview" />
    </div>
    """
  end
end
