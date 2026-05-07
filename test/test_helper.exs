ExUnit.start()
Tempest.Config.load!() |> Tempest.Storage.bootstrap!()
Ecto.Adapters.SQL.Sandbox.mode(Tempest.Repo, :manual)
