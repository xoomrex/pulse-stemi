defmodule Stemi.Repo do
  use Ecto.Repo,
    otp_app: :stemi,
    adapter: Ecto.Adapters.Postgres
end
