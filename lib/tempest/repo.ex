defmodule Tempest.Repo do
  use Ecto.Repo,
    otp_app: :tempest,
    adapter: Ecto.Adapters.Postgres
end
