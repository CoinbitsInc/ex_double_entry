import Config

config :ex_double_entry,
  ecto_repos: [ExDoubleEntry.Repo],
  db: :postgres,
  db_table_prefix: "ex_double_entry_",
  db_schema: "public",
  repo: ExDoubleEntry.Repo,
  default_currency: :USD,
  accounts: %{
    bank: [],
    savings: [positive_only: true],
    checking: []
  },
  transfers: %{
    deposit: [
      {:bank, :savings},
      {:bank, :checking},
      {:checking, :savings, reversible: true}
    ],
    withdraw: [
      {:savings, :checking}
    ]
  }

import_config "#{config_env()}.exs"
