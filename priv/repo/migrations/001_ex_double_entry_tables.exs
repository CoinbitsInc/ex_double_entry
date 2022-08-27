defmodule ExDoubleEntry.Repo.Migrations.ExDoubleEntryMoney do
  use Ecto.Migration

  def up do
    if custom_schema?() do
      execute "CREATE SCHEMA #{ExDoubleEntry.db_schema()}"
    end

    json_type =
      if ExDoubleEntry.Repo.__adapter__ == Ecto.Adapters.Postgres do
        :jsonb
      else
        :json
      end

    create table(:"#{ExDoubleEntry.db_table_prefix}account_balances", prefix: ExDoubleEntry.db_schema()) do
      add :identifier, :string, null: false
      add :currency, :string, null: false
      add :scope, :string, null: false, default: ""
      add :balance_amount, :decimal, null: false
      add :metadata, json_type

      timestamps(type: :utc_datetime_usec)
    end

    create index(:"#{ExDoubleEntry.db_table_prefix}account_balances", [:scope, :currency, :identifier], unique: true, name: :scope_currency_identifier_index, prefix: ExDoubleEntry.db_schema())

    create table(:"#{ExDoubleEntry.db_table_prefix}lines", prefix: ExDoubleEntry.db_schema()) do
      add :account_identifier, :string, null: false
      add :account_scope, :string, null: false, default: ""
      add :currency, :string, null: false
      add :amount, :decimal, null: false
      add :balance_amount, :decimal, null: false
      add :code, :string, null: false
      add :partner_identifier, :string, null: false
      add :partner_scope, :string, null: false, default: ""
      add :metadata, json_type
      add :idempotence, :uuid
      add :partner_line_id, references(:"#{ExDoubleEntry.db_table_prefix}lines")
      add :account_balance_id, references(:"#{ExDoubleEntry.db_table_prefix}account_balances"), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:"#{ExDoubleEntry.db_table_prefix}lines", [:code, :account_identifier, :currency, :inserted_at], name: :code_account_identifier_currency_inserted_at_index, prefix: ExDoubleEntry.db_schema())
    create index(:"#{ExDoubleEntry.db_table_prefix}lines", [:account_scope, :account_identifier, :currency, :inserted_at], name: :account_scope_account_identifier_currency_inserted_at_index, prefix: ExDoubleEntry.db_schema())
    create index(:"#{ExDoubleEntry.db_table_prefix}lines", [:idempotence], name: :idempotence, prefix: ExDoubleEntry.db_schema())
  end

  def down do
    if custom_schema?() do
      execute "DROP SCHEMA #{ExDoubleEntry.db_schema()}"
    else
      drop table(:"#{ExDoubleEntry.db_table_prefix}account_balances")
      drop table(:"#{ExDoubleEntry.db_table_prefix}lines")
    end
  end

  defp custom_schema? do
    !!ExDoubleEntry.db_schema() and ExDoubleEntry.db_schema() != "public"
  end
end
