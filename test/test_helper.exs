{:ok, _} = Application.ensure_all_started(:ex_machina)

ExUnit.start(timeout: 300_000)
ExUnit.configure(exclude: [stress_test: true])

require Logger

configuration = Application.get_env(:ex_double_entry, ExDoubleEntry.Repo)

if configuration[:pool] == Ecto.Adapters.SQL.Sandbox do
  Ecto.Adapters.SQL.Sandbox.mode(ExDoubleEntry.repo(), :manual)
else
  Logger.info("Repository is not running in a sandbox mode...")
end

db = Application.fetch_env!(:ex_double_entry, :db)
money = Application.fetch_env!(:ex_double_entry, :money)
Logger.info("Running tests with #{db} and #{money}...")
