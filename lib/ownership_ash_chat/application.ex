defmodule OwnershipAshChat.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      OwnershipAshChatWeb.Telemetry,
      OwnershipAshChat.Repo,
      {DNSCluster,
       query: Application.get_env(:ownership_ash_chat, :dns_cluster_query) || :ignore},
      {Oban,
       AshOban.config(
         Application.fetch_env!(:ownership_ash_chat, :ash_domains),
         Application.fetch_env!(:ownership_ash_chat, Oban)
       )},
      {Phoenix.PubSub, name: OwnershipAshChat.PubSub},
      # Start a worker by calling: OwnershipAshChat.Worker.start_link(arg)
      # {OwnershipAshChat.Worker, arg},
      # Start to serve requests, typically the last entry
      OwnershipAshChatWeb.Endpoint,
      {AshAuthentication.Supervisor, [otp_app: :ownership_ash_chat]}
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: OwnershipAshChat.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    OwnershipAshChatWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
