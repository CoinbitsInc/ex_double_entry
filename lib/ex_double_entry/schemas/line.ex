defmodule ExDoubleEntry.Line do
  use Ecto.Schema
  import Ecto.Changeset

  alias ExDoubleEntry.{AccountBalance, EctoType, Line, MoneyProxy}

  @schema_prefix ExDoubleEntry.db_schema()
  schema "#{ExDoubleEntry.db_table_prefix()}lines" do
    field :account_identifier, EctoType.Identifier
    field :account_scope, EctoType.Scope
    field :currency, EctoType.Currency
    field :amount, EctoType.Amount
    field :balance_amount, EctoType.Amount
    field :code, EctoType.Identifier
    field :partner_identifier, EctoType.Identifier
    field :partner_scope, EctoType.Scope
    field :metadata, :map
    field :idempotence, :binary_id

    belongs_to :partner_line, Line
    belongs_to :account_balance, AccountBalance

    timestamps type: :utc_datetime_usec
  end

  defp changeset(params) do
    %Line{}
    |> cast(params, [
      :account_identifier,
      :account_scope,
      :currency,
      :amount,
      :balance_amount,
      :code,
      :partner_identifier,
      :partner_scope,
      :metadata,
      :idempotence,
      :account_balance_id,
      :partner_line_id
    ])
    |> validate_required([
      :account_identifier,
      :currency,
      :amount,
      :balance_amount,
      :code,
      :partner_identifier
    ])
    |> foreign_key_constraint(:partner_line_id)
    |> foreign_key_constraint(:account_balance_id)
  end

  def insert!(money, attrs) do
    account = attrs[:account]
    partner = attrs[:partner]

    %{
      account_identifier: account.identifier,
      account_scope: account.scope,
      currency: money.currency,
      code: attrs[:code],
      amount: money.amount,
      balance_amount: MoneyProxy.add(account.balance, money).amount,
      partner_identifier: partner.identifier,
      partner_scope: partner.scope,
      metadata: attrs[:metadata],
      idempotence: attrs[:idempotence],
      account_balance_id: account.id
    }
    |> changeset()
    |> ExDoubleEntry.repo().insert!()
  end

  def update_partner_line_id!(%Line{} = line, partner_line_id) do
    line
    |> Ecto.Changeset.change(partner_line_id: partner_line_id)
    |> ExDoubleEntry.repo().update!()
  end
end
