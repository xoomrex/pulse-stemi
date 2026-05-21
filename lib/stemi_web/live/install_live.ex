defmodule StemiWeb.InstallLive do
  @moduledoc """
  Public install screen shown to non-admin users who try to access Pulse on a
  desktop. Admin desktop access bypasses this; mobile users never see it.
  """
  use StemiWeb, :live_view

  @impl true
  def mount(_params, session, socket) do
    device = session["device_type"] || "desktop"

    {:ok,
     socket
     |> assign(:page_title, "Install Pulse")
     |> assign(:device, device)
     |> assign(:url, nil), layout: false}
  end

  @impl true
  def handle_event("set_url", %{"url" => url}, socket) do
    {:noreply, assign(socket, :url, url)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="install-screen" id="install-screen" phx-hook="ReportUrl">
      <div class="install-screen__card">
        <div class="install-screen__icon">
          <img src="/icon-192.png" alt="Pulse" width="80" height="80" />
        </div>

        <h1 class="install-screen__title">Pulse runs on your phone</h1>
        <p class="install-screen__subtitle">
          This app is built for clinicians on the move. Open it on your phone and install it to the home screen.
        </p>

        <div class="install-screen__url-box">
          <div class="install-screen__url-label">Open on your phone:</div>
          <div class="install-screen__url" id="install-url">{@url || "—"}</div>
        </div>

        <div class="install-screen__steps">
          <div class="install-screen__step">
            <span class="install-screen__step-num">1</span>
            <span>Open this URL on your phone's browser.</span>
          </div>
          <div class="install-screen__step">
            <span class="install-screen__step-num">2</span>
            <span>iOS: tap <strong>Share → Add to Home Screen</strong>. Android: tap the <strong>Install</strong> banner.</span>
          </div>
          <div class="install-screen__step">
            <span class="install-screen__step-num">3</span>
            <span>Sign in. You'll get real-time STEMI alerts.</span>
          </div>
        </div>

        <p class="install-screen__admin-note">
          Admin? <a href="/login" class="install-screen__link">Sign in here</a> — admins can use Pulse on desktop.
        </p>
      </div>
    </div>

    <style>
      body { background: var(--bg-primary); }
      .install-screen {
        min-height: 100dvh;
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 24px;
        background:
          radial-gradient(ellipse at top, rgba(239,68,68,0.10), transparent 60%),
          var(--bg-primary);
      }
      .install-screen__card {
        max-width: 460px;
        width: 100%;
        background: linear-gradient(180deg, var(--bg-card) 0%, var(--bg-secondary) 100%);
        border: 1px solid var(--border);
        border-radius: 20px;
        padding: 36px 28px;
        text-align: center;
        box-shadow: 0 24px 60px rgba(0,0,0,0.6), 0 0 0 1px rgba(239,68,68,0.08) inset;
      }
      .install-screen__icon {
        margin: 0 auto 18px;
        width: 80px;
        height: 80px;
        animation: install-bob 3.2s ease-in-out infinite;
      }
      @keyframes install-bob {
        0%, 100% { transform: translateY(0); }
        50% { transform: translateY(-6px); }
      }
      .install-screen__icon img { border-radius: 18px; }
      .install-screen__title {
        font-size: 24px;
        font-weight: 700;
        margin-bottom: 10px;
        letter-spacing: -0.02em;
      }
      .install-screen__subtitle {
        color: var(--text-secondary);
        font-size: 14px;
        line-height: 1.55;
        margin-bottom: 24px;
      }
      .install-screen__url-box {
        background: var(--bg-input);
        border: 1px solid var(--border);
        border-radius: 12px;
        padding: 14px 16px;
        margin-bottom: 24px;
        text-align: left;
      }
      .install-screen__url-label {
        font-size: 11px;
        text-transform: uppercase;
        letter-spacing: 0.08em;
        color: var(--text-muted);
        margin-bottom: 6px;
      }
      .install-screen__url {
        font-family: ui-monospace, "SF Mono", Menlo, Consolas, monospace;
        font-size: 14px;
        word-break: break-all;
        color: var(--accent);
      }
      .install-screen__steps {
        display: flex;
        flex-direction: column;
        gap: 12px;
        margin-bottom: 24px;
        text-align: left;
      }
      .install-screen__step {
        display: flex;
        align-items: flex-start;
        gap: 12px;
        font-size: 14px;
        color: var(--text-secondary);
        line-height: 1.5;
      }
      .install-screen__step-num {
        flex-shrink: 0;
        width: 24px;
        height: 24px;
        border-radius: 50%;
        background: var(--accent);
        color: white;
        font-weight: 700;
        font-size: 12px;
        display: flex;
        align-items: center;
        justify-content: center;
      }
      .install-screen__admin-note {
        font-size: 13px;
        color: var(--text-muted);
        padding-top: 16px;
        border-top: 1px solid var(--border);
      }
      .install-screen__link {
        color: var(--accent);
        text-decoration: none;
        font-weight: 600;
      }
      .install-screen__link:hover { text-decoration: underline; }
    </style>
    """
  end
end
