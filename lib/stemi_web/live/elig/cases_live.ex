defmodule StemiWeb.Elig.CasesLive do
  use StemiWeb, :live_view

  alias Stemi.Cases
  alias Stemi.Cases.Case
  import StemiWeb.Components.StatsGrid
  use StemiWeb.EmsMapHelpers

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Cases.subscribe()

    cases = Cases.list_approved_cases()

    socket =
      socket
      |> assign(:page_title, "Patient Files")
      |> assign(:active_tab, :dashboard)
      |> assign(:cases, cases)
      |> assign(:selected_case, nil)
      |> assign(:mrn_value, "")
      |> assign(:preview_image, nil)
      |> assign(:stats, Cases.case_stats())
      |> assign(:show_map, false)

    {:ok, socket}
  end

  # Real-time update from PubSub
  @impl true
  def handle_info({event, _payload}, socket) when event in [:case_created, :case_er_updated, :case_cardiology_updated, :case_eligibility_updated, :case_ems_dispatched] do
    cases = Cases.list_approved_cases()

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
    {:noreply, assign(socket, selected_case: selected, mrn_value: selected.mrn_number || "")}
  end

  @impl true
  def handle_event("close_case", _params, socket) do
    {:noreply, assign(socket, selected_case: nil, mrn_value: "")}
  end

  @impl true
  def handle_event("update_mrn", %{"value" => mrn}, socket) do
    {:noreply, assign(socket, mrn_value: mrn)}
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
  def handle_event("save_mrn", _params, socket) do
    mrn = socket.assigns.mrn_value
    id = socket.assigns.selected_case.id
    user = socket.assigns.current_user
    case_record = Cases.get_case!(id)

    had_mrn = case_record.mrn_number != nil && case_record.mrn_number != ""

    if mrn != "" do
      result = Cases.update_case_eligibility(case_record, %{
        eligibility_id: user.id,
        mrn_number: String.trim(mrn),
        eligibility_decided_at: DateTime.truncate(DateTime.utc_now(), :second)
      })

      case result do
        {:ok, _} ->
          cases = Cases.list_approved_cases()
          msg = if had_mrn, do: "MRN updated!", else: "MRN assigned!"

          socket =
            socket
            |> put_flash(:info, msg)
            |> assign(:cases, cases)
            |> assign(:selected_case, nil)
            |> assign(:mrn_value, "")

          {:noreply, socket}

        {:error, changeset} ->
          IO.inspect(changeset, label: "MRN_SAVE_ERROR")
          {:noreply, put_flash(socket, :error, "Failed to save MRN")}
      end
    else
      {:noreply, put_flash(socket, :error, "Please enter an MRN number")}
    end
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
      .elig-overlay {
        position: fixed;
        inset: 0;
        background: rgba(0,0,0,0.7);
        z-index: 1000;
        display: flex;
        align-items: flex-end;
        justify-content: center;
      }
      .elig-panel {
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
      .elig-panel__handle {
        width: 40px;
        height: 4px;
        background: rgba(255,255,255,0.2);
        border-radius: 2px;
        margin: 0 auto 16px;
      }
      .elig-panel__title {
        font-size: 18px;
        font-weight: 700;
        margin-bottom: 16px;
      }
      .elig-field {
        display: flex;
        justify-content: space-between;
        align-items: center;
        padding: 10px 0;
        border-bottom: 1px solid var(--border, #333);
      }
      .elig-label {
        font-size: 13px;
        color: var(--text-muted, #888);
        font-weight: 500;
      }
      .elig-val {
        font-size: 15px;
        font-weight: 600;
      }
      .elig-photo {
        padding: 10px 0;
        border-bottom: 1px solid var(--border, #333);
      }
      .elig-photo .elig-label {
        display: block;
        margin-bottom: 10px;
      }
      .elig-photo img {
        width: 100%;
        border-radius: 8px;
        max-height: 250px;
        object-fit: contain;
        background: var(--bg-primary, #0f0f23);
        cursor: pointer;
      }
      .elig-btns {
        display: flex;
        gap: 8px;
        margin-top: 16px;
      }
    </style>

    <div class="section-header">
      <div>
        <h1 class="section-header__title">Patient Files</h1>
        <span class="section-header__count">{length(@cases)} cases</span>
      </div>
    </div>

    <.stats_grid stats={@stats} />

    <!-- Case List -->
    <div class="user-list" id="elig-list">
      <div
        :for={c <- @cases}
        class="user-card"
        style="cursor: pointer;"
        phx-click="view_case"
        phx-value-id={c.id}
        id={"elig-#{c.id}"}
      >
        <div class="user-card__avatar" style={"background: #{if c.mrn_number && c.mrn_number != "", do: "#22c55e", else: "#f59e0b"}"}>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <rect x="2" y="5" width="20" height="14" rx="2"/>
            <circle cx="8" cy="12" r="2"/>
            <path d="M14 10h4"/>
            <path d="M14 14h4"/>
          </svg>
        </div>
        <div class="user-card__info">
          <div class="user-card__name">{Case.display_id(c)} — {c.patient_id}</div>
          <div class="user-card__meta">
            <span :if={c.mrn_number && c.mrn_number != ""} class="badge" style="background: #22c55e22; color: #22c55e;">
              MRN: {c.mrn_number}
            </span>
            <span :if={!c.mrn_number || c.mrn_number == ""} class="badge" style="background: #f59e0b22; color: #f59e0b;">
              Needs MRN
            </span>
            <span style="color: var(--text-muted); font-size: 12px;">{time_ago(c.inserted_at)}</span>
          </div>
        </div>
        <div :if={!c.mrn_number || c.mrn_number == ""} style="color: var(--warning); font-size: 12px; font-weight: 600;">ASSIGN →</div>
        <div :if={c.mrn_number && c.mrn_number != ""} style="color: var(--success); font-size: 12px; font-weight: 600;">✓ DONE</div>
      </div>

      <div :if={@cases == []} class="empty-state">
        <div class="empty-state__icon">📋</div>
        <div class="empty-state__text">No approved cases waiting for MRN.</div>
      </div>
    </div>

    <!-- Sign Out -->
    <div style="margin-top: 24px;">
      
        
        <a href="/logout" class="btn btn--ghost btn--full" id="btn-logout">Sign Out</a>
      
    </div>

    <!-- Case Detail Modal -->
    <div :if={@selected_case} class="elig-overlay" id="elig-detail-modal">
      <div class="elig-panel">
        <div class="elig-panel__handle"></div>
        <h2 class="elig-panel__title">{Case.display_id(@selected_case)}</h2>

        <div class="elig-field">
          <span class="elig-label">Patient ID</span>
          <span class="elig-val">{@selected_case.patient_id}</span>
        </div>

        <div class="elig-field">
          <span class="elig-label">Submitted By</span>
          <span class="elig-val">{@selected_case.phc_user.full_name}</span>
        </div>

        <div :if={@selected_case.cardiologist} class="elig-field">
          <span class="elig-label">Approved By</span>
          <span class="elig-val" style="color: #22c55e;">✓ {@selected_case.cardiologist.full_name}</span>
        </div>

        <!-- ECG Image -->
        <div :if={@selected_case.ecg_photo_url && @selected_case.ecg_photo_url != "no_photo"} class="elig-photo">
          <span class="elig-label">ECG Photo (tap to enlarge)</span>
          <img src={@selected_case.ecg_photo_url} alt="ECG" phx-click="preview_image" phx-value-url={@selected_case.ecg_photo_url} />
        </div>

        <!-- ID Image -->
        <div :if={@selected_case.id_photo_url} class="elig-photo">
          <span class="elig-label">Patient ID Photo (tap to enlarge)</span>
          <img src={@selected_case.id_photo_url} alt="Patient ID" phx-click="preview_image" phx-value-url={@selected_case.id_photo_url} />
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

        <!-- MRN Input -->
        <div style="margin-top: 16px;">
          <div class="form-group">
            <label class="form-label" for="mrn_input">Medical Record Number (MRN)</label>
            <input
              class="form-input"
              type="text"
              id="mrn_input"
              value={@mrn_value}
              placeholder="Enter MRN number"
              autocomplete="off"
              phx-keyup="update_mrn"
            />
          </div>
          <div class="elig-btns">
            <button type="button" class="btn btn--ghost" style="flex:1" phx-click="close_case">Cancel</button>
            <button type="button" class="btn btn--primary" style="flex:2" phx-click="save_mrn" id="btn-save-mrn">
              {if @selected_case.mrn_number && @selected_case.mrn_number != "", do: "Update MRN", else: "Assign MRN"}
            </button>
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
    <div :if={@preview_image} class="img-lightbox" phx-click="close_preview" id="elig-img-lightbox">
      <button class="img-lightbox__close" phx-click="close_preview">✕</button>
      <img src={@preview_image} alt="Preview" />
    </div>

    <style>
      .img-lightbox { position: fixed; inset: 0; background: rgba(0,0,0,0.92); z-index: 2000; display: flex; align-items: center; justify-content: center; cursor: pointer; }
      .img-lightbox img { max-width: 95vw; max-height: 90vh; object-fit: contain; border-radius: 8px; }
      .img-lightbox__close { position: absolute; top: 16px; right: 16px; background: rgba(255,255,255,0.1); border: none; color: white; width: 40px; height: 40px; border-radius: 50%; font-size: 20px; cursor: pointer; display: flex; align-items: center; justify-content: center; }
    </style>
    """
  end
end
