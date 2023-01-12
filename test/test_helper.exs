require Logger

{:ok, _} = Application.ensure_all_started(:ex_machina)

ExUnit.start(timeout: 300_000)

if System.get_env("MIX_ENV") == "test_ex_money_concurrent_db_pool" do
  Logger.info("Repository is not running in a sandbox mode...")
  ExUnit.configure(exclude: [concurrent_db_pool: false])
else
  Ecto.Adapters.SQL.Sandbox.mode(ExDoubleEntry.repo(), :manual)
  ExUnit.configure(exclude: [concurrent_db_pool: true])
end

db = Application.fetch_env!(:ex_double_entry, :db)
money = Application.fetch_env!(:ex_double_entry, :money)
Logger.info("Running tests with #{db} and #{money}...")
