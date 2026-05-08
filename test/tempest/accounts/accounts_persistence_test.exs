defmodule Tempest.Accounts.PersistenceTest do
  use ExUnit.Case, async: false

  alias Tempest.{Accounts, Config, Repo, Storage}

  @password "correct horse battery staple"

  test "account creation persists across repo process restart" do
    data_dir =
      Path.join(System.tmp_dir!(), "tempest_accounts_persistence_#{System.unique_integer([:positive])}")

    config =
      Config.validate!(
        [
          hostname: "localhost",
          public_url: "http://localhost:4000",
          data_dir: data_dir,
          blob_max_bytes: 10_000_000
        ],
        env: :test
      )

    account_db = Config.account_db_path(config)
    previous_dynamic_repo = Repo.get_dynamic_repo()

    on_exit(fn ->
      Repo.put_dynamic_repo(previous_dynamic_repo)
      File.rm_rf(data_dir)
    end)

    assert :ok = Storage.bootstrap!(config)

    first_repo = start_repo!(account_db)
    Repo.put_dynamic_repo(first_repo)
    migrate!(first_repo)

    assert {:ok, created} =
             Accounts.create_account(%{
               "handle" => "persist.test",
               "email" => "persist@example.com",
               "password" => @password
             })

    assert created["handle"] == "persist.test"
    :ok = Supervisor.stop(first_repo)

    second_repo = start_repo!(account_db)
    Repo.put_dynamic_repo(second_repo)

    assert {:ok, session} = Accounts.create_session("persist.test", @password)
    assert session["did"] == created["did"]
    assert session["handle"] == "persist.test"

    :ok = Supervisor.stop(second_repo)
  end

  defp start_repo!(database) do
    {:ok, pid} =
      Repo.start_link(
        name: nil,
        database: database,
        pool: DBConnection.ConnectionPool,
        pool_size: 2,
        journal_mode: :wal,
        busy_timeout: 5_000,
        default_transaction_mode: :immediate
      )

    pid
  end

  defp migrate!(repo_pid) do
    Ecto.Migrator.run(Repo, "priv/repo/migrations", :up,
      all: true,
      dynamic_repo: repo_pid,
      log: false,
      log_migrations_sql: false,
      log_migrator_sql: false
    )
  end
end
