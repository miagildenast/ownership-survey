import Config

# Enable the dev-only study writing harness route so it can be tested.
config :ownership_ash_chat, dev_routes: true

# Fast, deterministic ping-pong: stub the AI responder. Three lines per run.
config :ownership_ash_chat,
  ping_pong_lines: 3,
  study_responder: {OwnershipAshChat.Study.PingPongStub, :reply}

# Tests run against a stable fixture config, not the real priv/study/config.yml, so
# editing the live study copy can never break the suite (see the fixture header).
config :ownership_ash_chat,
  study_config_path: "test/support/study/config.yml"

# Swap the notifications backend for a test double that forwards to a registered pid
# (see OwnershipAshChat.Notifications.TestBackend) instead of calling Telegram.
config :ownership_ash_chat,
       OwnershipAshChat.Notifications,
       OwnershipAshChat.Notifications.TestBackend

config :ash, policies: [show_policy_breakdowns?: true], disable_async?: true

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :ownership_ash_chat, OwnershipAshChat.Repo,
  database:
    Path.expand("../ownership_ash_chat_test#{System.get_env("MIX_TEST_PARTITION")}.db", __DIR__),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 5,
  # SQLite is single-writer; give concurrent connections time to acquire the
  # write lock instead of failing immediately ("database is locked").
  busy_timeout: 5000,
  journal_mode: :wal

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :ownership_ash_chat, OwnershipAshChatWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "shCMWBjkPpi2h/lbnS4sBgSVvk8K8R/QEA/hIQqz/vWfZeHTcOWjmBVHKyT4flbT",
  server: false

# In test we don't send emails
config :ownership_ash_chat, OwnershipAshChat.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true
