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
      <div class="blob blob-1"></div>
      <div class="blob blob-2"></div>
      <div class="blob blob-3"></div>
      <div class="blob blob-4"></div>
      <div class="blob blob-5"></div>
      <div class="blob blob-6"></div>

      <div class="login-card">
        <div class="login-logo">
          <div class="login-logo__ring"></div>
          <svg viewBox="0 0 64 64" fill="none" xmlns="http://www.w3.org/2000/svg">
            <circle cx="32" cy="32" r="30" stroke="#ef4444" stroke-width="1.5" opacity="0.2"/>
            <circle cx="32" cy="32" r="24" stroke="#ef4444" stroke-width="1" opacity="0.12"/>
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
            <label class="login-label" for="session_username">Username</label>
            <input
              class="login-input"
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
            <label class="login-label" for="session_password">Password</label>
            <input
              class="login-input"
              type="password"
              name="session[password]"
              id="session_password"
              placeholder="Enter your password"
              autocomplete="off"
              required
            />
          </div>

          <button type="submit" class="login-btn" id="btn-login">
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
        background: linear-gradient(135deg, #b91c1c 0%, #dc2626 30%, #ef4444 60%, #f43f5e 100%);
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 24px;
        position: relative;
        overflow: hidden;
      }

      /* Floating blobs */
      .blob {
        position: absolute;
        border-radius: 50%;
        animation: blob-float 7s ease-in-out infinite;
        pointer-events: none;
      }
      .blob-1 { width: 90px;  height: 90px;  background: #fbbf24; opacity: 0.4; top: 8%;   left: 6%;   animation-delay: 0s;   }
      .blob-2 { width: 55px;  height: 55px;  background: #f9a8d4; opacity: 0.45; top: 18%;  right: 10%; animation-delay: 1.2s; }
      .blob-3 { width: 130px; height: 130px; background: #fb923c; opacity: 0.3; bottom: 12%; left: 4%;  animation-delay: 2.5s; }
      .blob-4 { width: 45px;  height: 45px;  background: #a78bfa; opacity: 0.45; bottom: 22%; right: 7%; animation-delay: 0.8s; }
      .blob-5 { width: 70px;  height: 70px;  background: #34d399; opacity: 0.3; top: 58%;  left: 12%;  animation-delay: 1.8s; }
      .blob-6 { width: 35px;  height: 35px;  background: #fde68a; opacity: 0.5; top: 42%;  right: 5%;  animation-delay: 3.2s; }

      @keyframes blob-float {
        0%, 100% { transform: translateY(0) scale(1); }
        50%       { transform: translateY(-18px) scale(1.06); }
      }

      .login-card {
        width: 100%;
        max-width: 360px;
        background: rgba(255, 255, 255, 0.97);
        border-radius: 28px;
        padding: 36px 28px 28px;
        box-shadow: 0 24px 64px rgba(0,0,0,0.28);
        text-align: center;
        position: relative;
        z-index: 10;
      }

      .login-logo {
        margin-bottom: 16px;
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
        border: 2px solid #ef4444;
        opacity: 0;
        animation: login-pulse 2.4s ease-out infinite;
      }

      @keyframes login-pulse {
        0%   { transform: scale(0.8); opacity: 0.5; }
        50%  { transform: scale(1.4); opacity: 0; }
        100% { transform: scale(1.4); opacity: 0; }
      }

      .login-ecg {
        stroke-dasharray: 160;
        stroke-dashoffset: 160;
        animation: login-ecg-draw 2.4s ease-in-out infinite;
      }

      @keyframes login-ecg-draw {
        0%   { stroke-dashoffset: 160; opacity: 0.3; }
        30%  { opacity: 1; }
        60%  { stroke-dashoffset: 0; opacity: 1; }
        80%  { opacity: 0.5; }
        100% { stroke-dashoffset: -160; opacity: 0.3; }
      }

      .login-title {
        font-size: 36px;
        font-weight: 800;
        color: #dc2626;
        letter-spacing: -0.02em;
        margin-bottom: 4px;
      }

      .login-subtitle {
        font-size: 13px;
        color: #94a3b8;
        margin-bottom: 28px;
      }

      .login-form {
        text-align: left;
      }

      .login-form .form-group {
        margin-bottom: 18px;
      }

      .login-label {
        display: block;
        font-size: 13px;
        font-weight: 600;
        color: #475569;
        margin-bottom: 6px;
      }

      .login-input {
        width: 100%;
        padding: 12px 14px;
        background: #f8fafc;
        border: 1.5px solid #e2e8f0;
        border-radius: 12px;
        font-size: 15px;
        color: #1e293b;
        outline: none;
        box-sizing: border-box;
        transition: border-color 0.2s;
      }

      .login-input::placeholder {
        color: #cbd5e1;
      }

      .login-input:focus {
        border-color: #ef4444;
        background: #fff;
        box-shadow: 0 0 0 3px rgba(239,68,68,0.12);
      }

      .login-btn {
        width: 100%;
        margin-top: 8px;
        padding: 14px;
        background: linear-gradient(135deg, #dc2626, #ef4444);
        color: #fff;
        font-size: 16px;
        font-weight: 700;
        border: none;
        border-radius: 14px;
        cursor: pointer;
        box-shadow: 0 6px 20px rgba(239,68,68,0.4);
        transition: transform 0.15s, box-shadow 0.15s;
      }

      .login-btn:hover {
        transform: translateY(-1px);
        box-shadow: 0 8px 24px rgba(239,68,68,0.5);
      }

      .login-btn:active {
        transform: translateY(0);
      }

      .login-footer {
        margin-top: 28px;
        font-size: 11px;
        color: #94a3b8;
        letter-spacing: 0.08em;
        text-transform: uppercase;
      }

      .login-designer {
        margin-top: 6px;
        font-size: 10px;
        color: #cbd5e1;
        letter-spacing: 0.05em;
        font-style: italic;
      }
    </style>
    """
  end
end
