ExUnit.start()

config = Tempest.Config.load!()
File.rm_rf!(config.data_dir)
Tempest.Storage.bootstrap!(config)

Ecto.Adapters.SQL.Sandbox.mode(Tempest.Repo, :manual)
