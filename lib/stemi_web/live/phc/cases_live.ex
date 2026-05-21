defmodule StemiWeb.Phc.CasesLive do
  use StemiWeb, :live_view

  alias Stemi.Cases
  alias Stemi.Cases.Case
  import StemiWeb.Components.StatsGrid
  use StemiWeb.EmsMapHelpers

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Cases.subscribe()

    user = socket.assigns.current_user
    cases = Cases.list_cases_for_phc(user.id)

    socket =
      socket
      |> assign(:page_title, "My Cases")
      |> assign(:active_tab, :dashboard)
      |> assign(:cases, cases)
      |> assign(:show_form, false)
      |> assign(:changeset, nil)
      |> assign(:stats, Cases.case_stats())
      |> assign(:show_map, false)
      |> allow_upload(:ecg_photo, accept: :any, max_entries: 1, max_file_size: 8_000_000)
      |> allow_upload(:id_photo, accept: :any, max_entries: 1, max_file_size: 8_000_000)

    {:ok, socket}
  end

  # Real-time update from PubSub
  @impl true
  def handle_info({event, _payload}, socket) when event in [:case_created, :case_er_updated, :case_cardiology_updated, :case_eligibility_updated, :case_ems_dispatched] do
    user = socket.assigns.current_user
    cases = Cases.list_cases_for_phc(user.id)

    socket =
      socket
      |> assign(:cases, cases)
      |> assign(:stats, Cases.case_stats())
      |> push_event("play-alert", %{})

    {:noreply, socket}
  end

  @impl true
  def handle_event("new_case", _params, socket) do
    changeset = Cases.change_case(%Case{}, %{})

    socket =
      socket
      |> assign(:show_form, true)
      |> assign(:changeset, changeset)

    {:noreply, socket}
  end

  @impl true
  def handle_event("close_form", _params, socket) do
    {:noreply, assign(socket, show_form: false, changeset: nil)}
  end

  @impl true
  def handle_event("validate_case", %{"case" => case_params}, socket) do
    changeset =
      %Case{}
      |> Case.create_changeset(case_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, changeset: changeset)}
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref, "upload" => upload_name}, socket) do
    {:noreply, cancel_upload(socket, String.to_existing_atom(upload_name), ref)}
  end

  @impl true
  def handle_event("submit_case", %{"case" => case_params}, socket) do
    user = socket.assigns.current_user

    # Upload images to Supabase Storage (persistent across deploys)
    ecg_urls = consume_uploaded_entries(socket, :ecg_photo, fn %{path: path}, entry ->
      file_name = "ecg_#{entry.uuid}#{Path.extname(entry.client_name)}"
      case Stemi.SupabaseStorage.upload(path, file_name) do
        {:ok, url} -> {:ok, url}
        {:error, _} -> {:ok, "no_photo"}
      end
    end)

    id_urls = consume_uploaded_entries(socket, :id_photo, fn %{path: path}, entry ->
      file_name = "id_#{entry.uuid}#{Path.extname(entry.client_name)}"
      case Stemi.SupabaseStorage.upload(path, file_name) do
        {:ok, url} -> {:ok, url}
        {:error, _} -> {:ok, nil}
      end
    end)

    attrs =
      case_params
      |> Map.put("phc_user_id", user.id)
      |> Map.put("ecg_photo_url", List.first(ecg_urls) || "no_photo")
      |> Map.put("id_photo_url", List.first(id_urls))

    attrs = if user.hospital_id, do: Map.put(attrs, "phc_hospital_id", user.hospital_id), else: attrs

    case Cases.create_case(attrs) do
      {:ok, _case} ->
        cases = Cases.list_cases_for_phc(user.id)

        socket =
          socket
          |> put_flash(:info, "STEMI case submitted successfully!")
          |> assign(:cases, cases)
          |> assign(:show_form, false)
          |> assign(:changeset, nil)

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply, assign(socket, changeset: changeset)}
    end
  end

  # --- Helpers ---

  defp status_color("pending_review"), do: "#f59e0b"
  defp status_color("approved"), do: "#22c55e"
  defp status_color("rejected"), do: "#ef4444"
  defp status_color("dispatched"), do: "#3b82f6"
  defp status_color(_), do: "#6b7260"

  defp status_label("pending_review"), do: "Pending Review"
  defp status_label("approved"), do: "Approved"
  defp status_label("rejected"), do: "Rejected"
  defp status_label("dispatched"), do: "EMS Dispatched"
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

  @impl true
  def render(assigns) do
    ~H"""
    <div class="section-header">
      <div>
        <h1 class="section-header__title">
          My STEMI Cases
          <span class="live-dot" title="Real-time updates active">Live</span>
        </h1>
        <span class="section-header__count">{length(@cases)} cases</span>
      </div>
      <button class="btn btn--primary btn--sm" phx-click="new_case" id="btn-new-case">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round"><line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/></svg>
        New Case
      </button>
    </div>

    <.stats_grid stats={@stats} />

    <!-- Case List -->
    <div class="user-list" id="case-list">
      <div
        :for={c <- @cases}
        class="user-card"
        id={"case-#{c.id}"}
      >
        <div class="user-card__avatar" style={"background: #{status_color(c.status)}"}>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M22 12h-4l-3 9L9 3l-3 9H2"/>
          </svg>
        </div>
        <div class="user-card__info">
          <div class="user-card__name">
            {Case.display_id(c)}<span :if={c.patient_id && c.patient_id != ""}> — {c.patient_id}</span>
          </div>
          <div class="user-card__meta">
            <span class="badge" style={"background: #{status_color(c.status)}22; color: #{status_color(c.status)}"}>
              {status_label(c.status)}
            </span>
            <span :if={c.ecg_photo_url && c.ecg_photo_url != "no_photo"} style="color: var(--success); font-size: 12px;">📷 ECG</span>
            <span :if={c.id_photo_url} style="color: var(--info); font-size: 12px;">🪪 ID</span>
            <span :if={Cases.count_comments(c.id) > 0} style="color: var(--warning); font-size: 12px;">💬 {Cases.count_comments(c.id)}</span>
            <span class="case-elapsed" data-elapsed-since={DateTime.to_iso8601(c.inserted_at)}>{time_ago(c.inserted_at)}</span>
          </div>
        </div>
      </div>

      <div :if={@cases == []} class="empty-state">
        <div class="empty-state__icon">🏥</div>
        <div class="empty-state__text">No cases submitted yet.</div>
        <button class="btn btn--primary" phx-click="new_case">
          Submit First Case
        </button>
      </div>
    </div>

    <!-- Sign Out -->
    <div style="margin-top: 24px;">
      
        
        <a href="/logout" class="btn btn--ghost btn--full" id="btn-logout">Sign Out</a>
      
    </div>

    <!-- New Case Modal -->
    <div :if={@show_form} class="modal-overlay" id="case-modal">
      <div class="modal-panel" phx-click-away="close_form">
        <div class="modal-panel__handle"></div>
        <h2 class="modal-panel__title">New STEMI Case</h2>

        <.form :let={f} for={@changeset} phx-change="validate_case" phx-submit="submit_case" id="case-form">
          <div class="form-group">
            <label class="form-label" for="case_patient_id">
              Patient ID / National ID
              <span class="form-label__optional">optional</span>
            </label>
            <input
              class="form-input"
              type="text"
              name="case[patient_id]"
              id="case_patient_id"
              value={f[:patient_id].value}
              placeholder="Leave blank if unknown"
              inputmode="numeric"
            />
            <div :for={msg <- f[:patient_id].errors |> Enum.map(&elem(&1, 0))} class="form-error">{msg}</div>
          </div>

            <div class="form-group">
            <label class="form-label">ECG Photo</label>
            <div class="photo-upload-area" phx-drop-target={@uploads.ecg_photo.ref} id="ecg-upload-wrap" phx-hook="ImageCompress">
              <.live_file_input upload={@uploads.ecg_photo} class="photo-upload-input" />

              <div :if={@uploads.ecg_photo.entries == []} class="photo-upload-placeholder">
                <div class="photo-upload-icon">
                  <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/>
                    <circle cx="12" cy="13" r="4"/>
                  </svg>
                </div>
                <div class="photo-upload-text">Tap to take ECG photo</div>
                <div class="photo-upload-hint">or choose from gallery</div>
              </div>

              <div :for={entry <- @uploads.ecg_photo.entries} class="photo-preview">
                <.live_img_preview entry={entry} class="photo-preview-img" />
                <button type="button" class="photo-remove-btn" phx-click="cancel_upload" phx-value-ref={entry.ref} phx-value-upload="ecg_photo">✕</button>
                <div :if={entry.progress > 0 && entry.progress < 100} class="photo-progress">
                  <div class="photo-progress-bar" style={"width: #{entry.progress}%"}></div>
                </div>
              </div>
            </div>
          </div>

            <div class="form-group">
            <label class="form-label">Patient ID Photo</label>
            <div class="photo-upload-area" phx-drop-target={@uploads.id_photo.ref} id="id-upload-wrap" phx-hook="ImageCompress">
              <.live_file_input upload={@uploads.id_photo} class="photo-upload-input" />

              <div :if={@uploads.id_photo.entries == []} class="photo-upload-placeholder">
                <div class="photo-upload-icon">
                  <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round">
                    <rect x="2" y="5" width="20" height="14" rx="2"/>
                    <circle cx="8" cy="12" r="2"/>
                    <path d="M14 10h4"/>
                    <path d="M14 14h4"/>
                  </svg>
                </div>
                <div class="photo-upload-text">Tap to take ID photo</div>
                <div class="photo-upload-hint">or choose from gallery</div>
              </div>

              <div :for={entry <- @uploads.id_photo.entries} class="photo-preview">
                <.live_img_preview entry={entry} class="photo-preview-img" />
                <button type="button" class="photo-remove-btn" phx-click="cancel_upload" phx-value-ref={entry.ref} phx-value-upload="id_photo">✕</button>
              </div>
            </div>
          </div>

          <div class="form-group">
            <label class="form-label" for="case_initial_comment">
              First note
              <span class="form-label__optional">optional · starts the thread</span>
            </label>
            <textarea
              class="form-input form-textarea"
              name="case[initial_comment]"
              id="case_initial_comment"
              rows="3"
              placeholder="Anything the cardiologist should know — symptoms, meds, time of onset… Others can reply to this on the case."
            >{f[:initial_comment].value}</textarea>
            <div :for={msg <- f[:initial_comment].errors |> Enum.map(&elem(&1, 0))} class="form-error">{msg}</div>
          </div>

          <div class="flex gap-2 mt-4">
            <button type="button" class="btn btn--ghost" style="flex:1" phx-click="close_form">Cancel</button>
            <button type="submit" class="btn btn--primary" style="flex:2" phx-disable-with="Submitting…">
              Submit Case
            </button>
          </div>
        </.form>
      </div>
    </div>

    <style>
      .photo-upload-area {
        position: relative;
        background: var(--bg-input);
        border: 2px dashed var(--border);
        border-radius: var(--radius-sm);
        overflow: hidden;
        transition: border-color var(--transition);
        min-height: 120px;
      }

      .photo-upload-area:hover,
      .photo-upload-area:focus-within {
        border-color: var(--accent);
      }

      .photo-upload-input {
        position: absolute;
        inset: 0;
        width: 100%;
        height: 100%;
        opacity: 0;
        cursor: pointer;
        z-index: 2;
      }

      .photo-upload-placeholder {
        text-align: center;
        padding: 24px 16px;
        color: var(--text-muted);
        pointer-events: none;
      }

      .photo-upload-icon {
        margin-bottom: 8px;
        opacity: 0.6;
      }

      .photo-upload-text {
        font-size: 14px;
        font-weight: 500;
        color: var(--text-secondary);
      }

      .photo-upload-hint {
        font-size: 12px;
        margin-top: 4px;
      }

      .photo-preview {
        position: relative;
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 8px;
      }

      .photo-preview-img {
        max-width: 100%;
        max-height: 200px;
        border-radius: 8px;
        object-fit: contain;
      }

      .photo-remove-btn {
        position: absolute;
        top: 12px;
        right: 12px;
        width: 32px;
        height: 32px;
        border-radius: 50%;
        background: rgba(239, 68, 68, 0.9);
        color: white;
        border: none;
        font-size: 16px;
        cursor: pointer;
        display: flex;
        align-items: center;
        justify-content: center;
        z-index: 3;
      }

      .photo-progress {
        position: absolute;
        bottom: 12px;
        left: 12px;
        right: 12px;
        height: 4px;
        background: var(--border);
        border-radius: 2px;
        overflow: hidden;
      }

      .photo-progress-bar {
        height: 100%;
        background: var(--accent);
        transition: width 0.3s ease;
      }
    </style>
    """
  end
end
