defmodule ExDoubleEntry.Transfer do
  require Logger

  alias ExDoubleEntry.Account
  alias ExDoubleEntry.AccountBalance
  alias ExDoubleEntry.Guard
  alias ExDoubleEntry.Line
  alias ExDoubleEntry.MoneyProxy
  alias ExDoubleEntry.Transfer

  @type t() :: %__MODULE__{}
  @type result() :: {:ok, %__MODULE__{}} | {:error, atom(), String.t()}

  @enforce_keys [:money, :from, :to, :code]
  defstruct [:money, :from, :to, :code, :metadata, :idempotence]

  def perform!(%Transfer{} = transfer) do
    perform!(transfer, ensure_accounts: true)
  end

  def perform!(transfer_attrs) do
    perform!(transfer_attrs, ensure_accounts: true)
  end

  def perform!(%Transfer{} = transfer, ensure_accounts: ensure_accounts) do
    with {:ok, _} <- Guard.positive_amount?(transfer),
         {:ok, _} <- Guard.valid_definition?(transfer),
         {:ok, _} <- Guard.matching_currency?(transfer) do
      perform(transfer, ensure_accounts: ensure_accounts)
    end
  end

  def perform!(transfer_attrs, ensure_accounts: ensure_accounts) do
    Transfer |> struct(transfer_attrs) |> perform!(ensure_accounts: ensure_accounts)
  end

  def perform(%Transfer{} = transfer) do
    perform(transfer, ensure_accounts: true)
  end

  def perform(%Transfer{} = transfer, opts) do
    Logger.debug(fn -> "Attempting transfer: #{inspect(transfer)}" end)

    [
      transfer.from,
      transfer.to
    ]
    |> AccountBalance.lock_multi!(&do_perform(transfer, &1, opts))
    |> parse_database_transaction_result()
  end

  defp do_perform(transfer, accounts, ensure_accounts: ensure_accounts) when is_list(accounts) do
    transfer = ensure_accounts_if_needed!(ensure_accounts, transfer, accounts)

    with {:ok, _} <- Guard.idempotent_if_provided?(transfer),
         {:ok, _} <- Guard.positive_balance_if_enforced?(transfer) do
      line1 =
        Line.insert!(MoneyProxy.neg(transfer.money),
          account: transfer.from,
          partner: transfer.to,
          code: transfer.code,
          metadata: transfer.metadata,
          idempotence: transfer.idempotence
        )

      line2 =
        Line.insert!(transfer.money,
          account: transfer.to,
          partner: transfer.from,
          code: transfer.code,
          metadata: transfer.metadata,
          idempotence: transfer.idempotence
        )

      Line.update_partner_line_id!(line1, line2.id)
      Line.update_partner_line_id!(line2, line1.id)

      from_amount = MoneyProxy.subtract(transfer.from.balance, transfer.money).amount
      to_amount = MoneyProxy.add(transfer.to.balance, transfer.money).amount

      AccountBalance.update_balance!(transfer.from, from_amount)
      AccountBalance.update_balance!(transfer.to, to_amount)

      Logger.debug(fn -> "Completed transfer: #{inspect(transfer)}" end)

      transfer
    end
  end

  defp ensure_accounts_if_needed!(true, %Transfer{} = transfer, accounts) do
    case accounts do
      [%Account{} = from, %Account{} = to] ->
        %{transfer | from: from, to: to}

      [%Account{} = from, nil] ->
        %{
          transfer
          | from: from,
            to: transfer.to |> AccountBalance.for_account!() |> Account.present()
        }

      [nil, %Account{} = to] ->
        %{
          transfer
          | from: transfer.from |> AccountBalance.for_account!() |> Account.present(),
            to: to
        }

      [nil, nil] ->
        %{
          transfer
          | from: transfer.from |> AccountBalance.for_account!() |> Account.present(),
            to: transfer.to |> AccountBalance.for_account!() |> Account.present()
        }
    end
  end

  defp ensure_accounts_if_needed!(false, %Transfer{} = transfer, accounts) do
    case accounts do
      [%Account{} = from, %Account{} = to] ->
        %{transfer | from: from, to: to}

      _ ->
        raise Account.NotFoundError
    end
  end

  defp parse_database_transaction_result({:ok, result} = tuple) when is_tuple(result) do
    if elem(result, 0) == :error do
      result
    else
      tuple
    end
  end

  defp parse_database_transaction_result(result), do: result
end
