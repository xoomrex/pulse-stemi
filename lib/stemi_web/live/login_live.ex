defmodule StemiWeb.LoginLive do
  use StemiWeb, :live_view

  @impl true
  def mount(_params, session, socket) do
    # If already logged in, redirect to dashboard
    if session["user_id"] do
      {:ok, push_navigate(socket, to: "/dashboard")}
    else
      socket =
        socket
        |> assign(:page_title, "Login")
        |> assign(:error, nil)

      {:ok, socket, layout: false}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="login-screen">
      <div class="login-card">
        <div class="login-logo">
          <div class="login-logo__ring"></div>
          <svg viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg">
            <circle cx="32" cy="32" r="30" stroke="#ef4444" stroke-width="1.5" opacity="0.15"/>
            <circle cx="32" cy="32" r="24" stroke="#ef4444" stroke-width="1" opacity="0.08"/>
            <path class="login-ecg" d="M8 32 L18 32 L22 20 L28 46 L32 14 L36 42 L40 24 L44 32 L56 32" stroke="#ef4444" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" fill="none"/>
          </svg>
        </div>
        <h1 class="login-title">Pulse</h1>
        <p class="login-subtitle">STEMI Coordination System</p>

        <div :if={Phoenix.Flash.get(@flash, :error)} class="flash flash--error" style="margin-bottom: 16px; text-align: left;">
          {Phoenix.Flash.get(@flash, :error)}
        </div>
        <div :if={Phoenix.Flash.get(@flash, :info)} class="flash flash--info" style="margin-bottom: 16px; text-align: left;">
          {Phoenix.Flash.get(@flash, :info)}
        </div>

        <form action="/session" method="post" class="login-form" id="login-form" autocomplete="off">
          <input type="hidden" name="_csrf_token" value={Phoenix.Controller.get_csrf_token()} />

          <div class="form-group">
            <label class="form-label" for="session_username">Username</label>
            <input
              class="form-input"
              type="text"
              name="session[username]"
              id="session_username"
              placeholder="Enter your username"
              autocapitalize="off"
              autocomplete="off"
              required
            />
          </div>

          <div class="form-group">
            <label class="form-label" for="session_password">Password</label>
            <input
              class="form-input"
              type="password"
              name="session[password]"
              id="session_password"
              placeholder="Enter your password"
              autocomplete="off"
              required
            />
          </div>

          <button type="submit" class="btn btn--primary btn--full" id="btn-login">
            Sign In
          </button>
        </form>

        <p class="login-footer">KFMC Disaster Management Department</p>
        <p class="login-designer">Designed by Saud Nahdi</p>
      </div>
    </div>

    <style>
      .login-screen {
        min-height: 100dvh;
        background: var(--bg-primary);
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 16px;
      }

      .login-card {
        width: 100%;
        max-width: 360px;
        text-align: center;
      }

      .login-logo {
        margin-bottom: 20px;
        position: relative;
        width: 80px;
        height: 80px;
        margin-left: auto;
        margin-right: auto;
      }

      .login-logo svg {
        width: 80px;
        height: 80px;
        position: relative;
        z-index: 1;
      }

      .login-logo__ring {
        position: absolute;
        inset: -8px;
        border-radius: 50%;
        border: 2px solid var(--accent);
        opacity: 0;
        animation: login-pulse 2.4s ease-out infinite;
      }

      @keyframes login-pulse {
        0% { transform: scale(0.8); opacity: 0.5; }
        50% { transform: scale(1.4); opacity: 0; }
        100% { transform: scale(1.4); opacity: 0; }
      }

      .login-ecg {
        stroke-dasharray: 160;
        stroke-dashoffset: 160;
        animation: login-ecg-draw 2.4s ease-in-out infinite;
      }

      @keyframes login-ecg-draw {
        0% { stroke-dashoffset: 160; opacity: 0.3; }
        30% { opacity: 1; }
        60% { stroke-dashoffset: 0; opacity: 1; }
        80% { opacity: 0.5; }
        100% { stroke-dashoffset: -160; opacity: 0.3; }
      }

      .login-title {
        font-size: 36px;
        font-weight: 800;
        color: var(--accent);
        letter-spacing: -0.02em;
        margin-bottom: 4px;
      }

      .login-subtitle {
        font-size: 14px;
        color: var(--text-muted);
        margin-bottom: 32px;
      }

      .login-form {
        text-align: left;
      }

      .login-form .form-group {
        margin-bottom: 20px;
      }

      .login-form .btn {
        margin-top: 8px;
        font-size: 16px;
        padding: 14px;
      }

      .login-footer {
        margin-top: 32px;
        font-size: 11px;
        color: var(--text-muted);
        letter-spacing: 0.08em;
        text-transform: uppercase;
      }

      .login-designer {
        margin-top: 6px;
        font-size: 10px;
        color: var(--text-muted);
        opacity: 0.7;
        letter-spacing: 0.05em;
        font-style: italic;
      }
    </style>
    """
  end
end
