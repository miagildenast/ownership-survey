defmodule OwnershipAshChat.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    # Load + validate the study configuration before anything starts. Invalid or
    # missing config raises here and aborts boot (fail-fast).
    OwnershipAshChat.Study.Config.load!()

    children = [
      OwnershipAshChatWeb.Telemetry,
      OwnershipAshChat.Repo,
      {DNSCluster,
       query: Application.get_env(:ownership_ash_chat, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: OwnershipAshChat.PubSub},
      # Start a worker by calling: OwnershipAshChat.Worker.start_link(arg)
      # {OwnershipAshChat.Worker, arg},
      # Start to serve requests, typically the last entry
      OwnershipAshChatWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: OwnershipAshChat.Supervisor]
    result = Supervisor.start_link(children, opts)

    # --- DEV: seed a writing run on boot & print its link (delete this block) ---
    if Application.get_env(:ownership_ash_chat, OwnershipAshChatWeb.Endpoint)[:code_reloader] do
      Task.start(&seed_dev_run/0)
    end

    # --- end DEV seed ---

    result
  end

  # --- DEV: boot-time writing-run seeder (delete with the block above) ---
  defp seed_dev_run do
    # os_time, not System.unique_integer/1: the latter restarts at small values on
    # every VM boot and collides with sessions persisted by earlier boots.
    session =
      OwnershipAshChat.Study.create_session!(%{
        case_id: "boot-#{System.os_time(:millisecond)}",
        topic_source_order: [:free, :assigned]
      })

    run =
      OwnershipAshChat.Study.create_run!(%{
        run_index: 1,
        topic_source: :free,
        ai_mode: :with_ai,
        session_id: session.id
      })

    port = OwnershipAshChatWeb.Endpoint.config(:http)[:port] || 4000

    Logger.info("""

    ┌─ DEV writing run ready ─────────────────────────────
    │ http://localhost:#{port}/dev/study/run/#{run.id}
    └─────────────────────────────────────────────────────
    """)
  rescue
    e -> Logger.warning("dev seed failed: #{Exception.message(e)}")
  end

  # --- end DEV seeder ---

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    OwnershipAshChatWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
