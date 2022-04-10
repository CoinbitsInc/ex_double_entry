defmodule ExDoubleEntry.Guard do
  alias ExDoubleEntry.{MoneyProxy, Transfer}

  @doc """
  ## Examples

  iex> %Transfer{money: MoneyProxy.new(42, :USD), from: nil, to: nil, code: nil}
  iex> |> Guard.positive_amount?()
  {:ok, %Transfer{money: MoneyProxy.new(42, :USD), from: nil, to: nil, code: nil}}

  iex> {:error, :positive_amount_only, %ExDoubleEntry.Transfer{}} =
  iex>   %Transfer{money: MoneyProxy.new(-42, :USD), from: nil, to: nil, code: nil}
  iex>   |> Guard.positive_amount?()
  iex> true
  true
  """
  def positive_amount?(%Transfer{money: money} = transfer) do
    case MoneyProxy.positive?(money) do
      true -> {:ok, transfer}
      false -> {:error, :positive_amount_only, transfer}
    end
  end

  @doc """
  ## Examples

  iex> %Transfer{
  iex>   money: nil,
  iex>   from: %Account{identifier: :savings, currency: :USD},
  iex>   to: %Account{identifier: :checking, currency: :USD},
  iex>   code: :deposit_reversal
  iex> }
  iex> |> Guard.valid_definition?()
  {
    :ok,
    %Transfer{
      money: nil,
      code: :deposit,
      from: %Account{identifier: :checking, currency: :USD},
      to: %Account{identifier: :savings, currency: :USD},
    }
  }

  iex> %Transfer{
  iex>   money: nil,
  iex>   from: %Account{identifier: :savings, currency: :USD},
  iex>   to: %Account{identifier: :checking, currency: :USD},
  iex>   code: :give_away_reversal
  iex> }
  iex> |> Guard.valid_definition?()
  {:error, :undefined_transfer_code, "Transfer code :give_away is undefined."}

  iex> %Transfer{
  iex>   money: nil,
  iex>   from: %Account{identifier: :savings, currency: :USD},
  iex>   to: %Account{identifier: :bank, currency: :USD},
  iex>   code: :deposit_reversal
  iex> }
  iex> |> Guard.valid_definition?()
  {:error, :undefined_transfer_pair, "Transfer pair :bank -> :savings does not exist for code :deposit_reversal."}

  iex> %Transfer{
  iex>   money: nil,
  iex>   from: %Account{identifier: :checking, currency: :USD},
  iex>   to: %Account{identifier: :savings, currency: :USD},
  iex>   code: :withdraw_reversal
  iex> }
  iex> |> Guard.valid_definition?()
  {:error, :undefined_transfer_pair, "Transfer pair :savings -> :checking does not exist for code :withdraw_reversal."}
  """
  def valid_definition?(%Transfer{from: from, to: to, code: code} = transfer) do
    case String.ends_with?("#{code}", "_reversal") do
      true ->
        valid_definition?(
          %Transfer{
            transfer
            | from: to,
              to: from,
              code:
                "#{code}"
                |> String.replace_suffix("_reversal", "")
                |> String.to_atom()
          },
          true
        )

      false ->
        valid_definition?(transfer, false)
    end
  end

  @doc """
  ## Examples

  iex> %Transfer{
  iex>   money: nil,
  iex>   from: %Account{identifier: :checking, currency: :USD},
  iex>   to: %Account{identifier: :savings, currency: :USD},
  iex>   code: :deposit
  iex> }
  iex> |> Guard.valid_definition?()
  {
    :ok,
    %Transfer{
      money: nil,
      code: :deposit,
      from: %Account{identifier: :checking, currency: :USD},
      to: %Account{identifier: :savings, currency: :USD},
    }
  }

  iex> %Transfer{
  iex>   money: nil,
  iex>   from: %Account{identifier: :checking, currency: :USD},
  iex>   to: %Account{identifier: :savings, currency: :USD},
  iex>   code: :deposit
  iex> }
  iex> |> Guard.valid_definition?(true)
  {
    :ok,
    %Transfer{
      money: nil,
      code: :deposit,
      from: %Account{identifier: :checking, currency: :USD},
      to: %Account{identifier: :savings, currency: :USD},
    }
  }

  iex> %Transfer{
  iex>   money: nil,
  iex>   from: %Account{identifier: :checking, currency: :USD},
  iex>   to: %Account{identifier: :savings, currency: :USD},
  iex>   code: :give_away
  iex> }
  iex> |> Guard.valid_definition?()
  {:error, :undefined_transfer_code, "Transfer code :give_away is undefined."}

  iex> %Transfer{
  iex>   money: nil,
  iex>   from: %Account{identifier: :checking, currency: :USD},
  iex>   to: %Account{identifier: :savings, currency: :USD},
  iex>   code: :withdraw
  iex> }
  iex> |> Guard.valid_definition?()
  {:error, :undefined_transfer_pair, "Transfer pair :checking -> :savings does not exist for code :withdraw."}

  iex> %Transfer{
  iex>   money: nil,
  iex>   from: nil,
  iex>   to: %Account{identifier: :savings, currency: :USD},
  iex>   code: :withdraw
  iex> }
  iex> |> Guard.valid_definition?()
  {:error, :missing_from_account, "Transfer must have a from account."}

  iex> %Transfer{
  iex>   money: nil,
  iex>   from: %Account{identifier: :checking, currency: :USD},
  iex>   to: nil,
  iex>   code: :withdraw
  iex> }
  iex> |> Guard.valid_definition?()
  {:error, :missing_to_account, "Transfer must have a to account."}
  """
  def valid_definition?(%Transfer{from: nil}, _is_reversal) do
    {:error, :missing_from_account, "Transfer must have a from account."}
  end

  def valid_definition?(%Transfer{to: nil}, _is_reversal) do
    {:error, :missing_to_account, "Transfer must have a to account."}
  end

  def valid_definition?(
        %Transfer{from: from, to: to, code: code} = transfer,
        is_reversal
      ) do
    with {:ok, pairs} <-
           :ex_double_entry
           |> Application.fetch_env!(:transfers)
           |> Map.fetch(code),
         true <-
           pairs
           |> Enum.find(fn pair ->
             accounts_match =
               [from.identifier, to.identifier] ==
                 pair
                 |> Tuple.to_list()
                 |> Enum.take(2)

             reversal_match =
               if is_reversal do
                 case pair do
                   {_to, _from, opts} ->
                     Keyword.take(opts, [:reversible]) == [reversible: true]

                   {_to, _from} ->
                     false
                 end
               else
                 true
               end

             accounts_match and reversal_match
           end)
           |> Kernel.!=(nil) do
      {:ok, transfer}
    else
      :error ->
        {:error, :undefined_transfer_code, "Transfer code :#{code} is undefined."}

      false ->
        code =
          if is_reversal do
            :"#{code}_reversal"
          else
            code
          end

        {:error, :undefined_transfer_pair,
         "Transfer pair :#{from.identifier} -> :#{to.identifier} does not exist for code :#{code}."}
    end
  end

  @doc """
  ## Examples

  iex> %Transfer{
  iex>   money: MoneyProxy.new(42, :USD),
  iex>   from: %Account{identifier: :checking, currency: :USD},
  iex>   to: %Account{identifier: :savings, currency: :USD},
  iex>   code: :deposit
  iex> }
  iex> |> Guard.matching_currency?()
  {
    :ok,
    %Transfer{
      money: MoneyProxy.new(42, :USD),
      code: :deposit,
      from: %Account{identifier: :checking, currency: :USD},
      to: %Account{identifier: :savings, currency: :USD},
    }
  }

  iex> %Transfer{
  iex>   money: MoneyProxy.new(42, :AUD),
  iex>   from: %Account{identifier: :checking, currency: :USD},
  iex>   to: %Account{identifier: :savings, currency: :USD},
  iex>   code: :deposit
  iex> }
  iex> |> Guard.matching_currency?()
  {:error, :mismatched_currencies, "Attempted to transfer :AUD from :checking in :USD to :savings in :USD."}

  iex> %Transfer{
  iex>   money: MoneyProxy.new(42, :USD),
  iex>   from: %Account{identifier: :checking, currency: :USD},
  iex>   to: %Account{identifier: :savings, currency: :AUD},
  iex>   code: :deposit
  iex> }
  iex> |> Guard.matching_currency?()
  {:error, :mismatched_currencies, "Attempted to transfer :USD from :checking in :USD to :savings in :AUD."}
  """
  def matching_currency?(%Transfer{money: money, from: from, to: to} = transfer) do
    if from.currency == money.currency and to.currency == money.currency do
      {:ok, transfer}
    else
      {:error, :mismatched_currencies,
       "Attempted to transfer :#{money.currency} from :#{from.identifier} in :#{from.currency} to :#{to.identifier} in :#{to.currency}."}
    end
  end

  @doc """
  ## Examples

  iex> %Transfer{
  iex>   money: MoneyProxy.new(42, :USD),
  iex>   from: %Account{identifier: :checking, currency: :USD, balance: MoneyProxy.new(42, :USD), positive_only?: true},
  iex>   to: %Account{identifier: :savings, currency: :USD},
  iex>   code: :deposit
  iex> }
  iex> |> Guard.positive_balance_if_enforced?()
  {
    :ok,
    %Transfer{
      money: MoneyProxy.new(42, :USD),
      code: :deposit,
      from: %Account{identifier: :checking, currency: :USD, balance: MoneyProxy.new(42, :USD), positive_only?: true},
      to: %Account{identifier: :savings, currency: :USD},
    }
  }

  iex> %Transfer{
  iex>   money: MoneyProxy.new(42, :USD),
  iex>   from: %Account{identifier: :checking, currency: :USD, balance: MoneyProxy.new(10, :USD), positive_only?: false},
  iex>   to: %Account{identifier: :savings, currency: :USD},
  iex>   code: :deposit
  iex> }
  iex> |> Guard.positive_balance_if_enforced?()
  {
    :ok,
    %Transfer{
      money: MoneyProxy.new(42, :USD),
      code: :deposit,
      from: %Account{identifier: :checking, currency: :USD, balance: MoneyProxy.new(10, :USD), positive_only?: false},
      to: %Account{identifier: :savings, currency: :USD},
    }
  }

  iex> %Transfer{
  iex>   money: MoneyProxy.new(42, :USD),
  iex>   from: %Account{identifier: :checking, currency: :USD, balance: MoneyProxy.new(10, :USD)},
  iex>   to: %Account{identifier: :savings, currency: :USD},
  iex>   code: :deposit
  iex> }
  iex> |> Guard.positive_balance_if_enforced?()
  {
    :ok,
    %Transfer{
      money: MoneyProxy.new(42, :USD),
      code: :deposit,
      from: %Account{identifier: :checking, currency: :USD, balance: MoneyProxy.new(10, :USD), positive_only?: nil},
      to: %Account{identifier: :savings, currency: :USD},
    }
  }

  iex> %Transfer{
  iex>   money: MoneyProxy.new(42, :USD),
  iex>   from: %Account{identifier: :checking, currency: :USD, balance: MoneyProxy.new(10, :USD), positive_only?: true},
  iex>   to: %Account{identifier: :savings, currency: :USD},
  iex>   code: :deposit
  iex> }
  iex> |> Guard.positive_balance_if_enforced?()
  {:error, :insufficient_balance, "Transfer: USD 42, :checking balance amount: 10"}
  """
  def positive_balance_if_enforced?(%Transfer{money: money, from: from} = transfer) do
    if !!from.positive_only? and MoneyProxy.cmp(from.balance, money) == :lt do
      {:error, :insufficient_balance,
       "Transfer: #{money.currency} #{money.amount}, :#{from.identifier} balance amount: #{from.balance.amount}"}
    else
      {:ok, transfer}
    end
  end
end
