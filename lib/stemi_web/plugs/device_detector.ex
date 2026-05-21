defmodule StemiWeb.Plugs.DeviceDetector do
  @moduledoc """
  Classifies the request as `:mobile` or `:desktop` based on the `User-Agent`
  header. Stored in the session so LiveView `on_mount` callbacks can enforce
  the desktop gate. Server-side only — never trust the client to set this.
  """
  import Plug.Conn

  @mobile_hints ~w(
    iphone ipod android blackberry windows\ phone iemobile
    opera\ mini opera\ mobi mobile silk fennec maemo
    pixel sm-g sm-a sm-n sm-s sm-t huawei oppo xiaomi redmi
  )

  @tablet_hints ~w(ipad tablet kindle silk-tablet sm-t playbook)

  def init(opts), do: opts

  def call(conn, _opts) do
    device_type = detect(conn)

    conn
    |> put_session(:device_type, Atom.to_string(device_type))
    |> assign(:device_type, device_type)
  end

  defp detect(conn) do
    ua =
      case get_req_header(conn, "user-agent") do
        [value | _] -> String.downcase(value)
        _ -> ""
      end

    cond do
      ua == "" -> :desktop
      Enum.any?(@mobile_hints, &String.contains?(ua, &1)) -> :mobile
      Enum.any?(@tablet_hints, &String.contains?(ua, &1)) -> :mobile
      true -> :desktop
    end
  end
end
