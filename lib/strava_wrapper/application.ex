defmodule StravaWrapper.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @env Mix.env()

  @impl true
  def start(_type, _args) do
    base_children = [
      StravaWrapperWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:strava_wrapper, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: StravaWrapper.PubSub},
      StravaWrapperWeb.Endpoint
    ]

    store_child = if @env != :test, do: [StravaWrapper.ActivityStore], else: []
    children = store_child ++ base_children

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: StravaWrapper.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    StravaWrapperWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
