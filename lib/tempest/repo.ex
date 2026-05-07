defmodule Tempest.Repo do
  use Ecto.Repo,
    otp_app: :tempest,
    adapter: Ecto.Adapters.SQLite3
end
