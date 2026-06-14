defmodule Tempest.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    config = Tempest.Config.load!()
    Tempest.Storage.bootstrap!(config)
    Tempest.Lexicon.Registry.validate_startup!()

    children = [
      TempestWeb.Telemetry,
      Tempest.Repo,
      Tempest.Blobs.GarbageCollector,
      {DNSCluster, query: Application.get_env(:tempest, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Tempest.PubSub},
      # Start a worker by calling: Tempest.Worker.start_link(arg)
      # {Tempest.Worker, arg},
      # Start to serve requests, typically the last entry
      TempestWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Tempest.Supervisor]

    with {:ok, pid} <- Supervisor.start_link(children, opts) do
      maybe_request_crawl()
      {:ok, pid}
    end
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TempestWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp maybe_request_crawl do
    if Application.get_env(:tempest, :env, :prod) != :test do
      Task.start(fn -> Tempest.Sync.request_own_crawl() end)
    end

    :ok
  end
end
