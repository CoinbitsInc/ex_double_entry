import Config

config :ex_double_entry,
  db: :postgres,
  money: :ex_money

config :ex_double_entry, ExDoubleEntry.Repo,
  username: System.get_env("POSTGRES_DB_USERNAME", "postgres"),
  password: System.get_env("POSTGRES_DB_PASSWORD", "postgres"),
  database: System.get_env("POSTGRES_DB_NAME", "ex_double_entry_test"),
  hostname: System.get_env("POSTGRES_DB_HOST", "localhost"),
  pool_size: 16,
  show_sensitive_data_on_connection_error: true,
  timeout: :infinity,
  queue_target: 500,
  queue_interval: 10

config :logger, level: :info

config :ex_money,
  default_cldr_backend: ExDoubleEntry.Cldr
