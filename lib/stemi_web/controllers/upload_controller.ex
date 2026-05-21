defmodule StemiWeb.UploadController do
  @moduledoc """
  Serves uploaded files from the writable upload directory.
  On Gigalixir (production), files are stored in /tmp/uploads.
  In development, files are stored in priv/static/uploads.
  """
  use StemiWeb, :controller

  def show(conn, %{"filename" => filename}) do
    # Sanitize filename to prevent directory traversal
    safe_name = Path.basename(filename)
    path = Path.join(upload_dir(), safe_name)

    if File.exists?(path) do
      content_type = MIME.from_path(safe_name)

      conn
      |> put_resp_content_type(content_type)
      |> put_resp_header("cache-control", "public, max-age=3600")
      |> send_file(200, path)
    else
      conn
      |> put_status(:not_found)
      |> text("File not found")
    end
  end

  @doc "Returns the writable upload directory for the current environment."
  def upload_dir do
    if System.get_env("GIGALIXIR") || System.get_env("PHX_HOST") do
      "/tmp/uploads"
    else
      Path.join(["priv/static/uploads"])
    end
  end
end
