defmodule ExDoubleEntry.ReversalTest do
  use ExDoubleEntry.DataCase
  alias ExDoubleEntry.{Account, Line, MoneyProxy, Reversal, Transfer}
  doctest Reversal

  setup do
    acc_a =
      :account_balance
      |> insert(identifier: :checking, balance_amount: 200_00)
      |> Account.present()

    acc_b =
      :account_balance
      |> insert(identifier: :savings, balance_amount: 200_00)
      |> Account.present()

    [acc_a: acc_a, acc_b: acc_b]
  end

  describe "perform!/1" do
    test "successful on params", %{acc_a: acc_a, acc_b: acc_b} do
      transfer =
        Reversal.perform!(
          money: MoneyProxy.new(123_45, :USD),
          from: acc_a,
          to: acc_b,
          code: :deposit
        )

      assert {:ok, %Transfer{}} = transfer
      assert Line |> ExDoubleEntry.repo().all() |> Enum.count() == 2
    end

    test "successful on struct", %{acc_a: acc_a, acc_b: acc_b} do
      transfer =
        Reversal.perform!(%Transfer{
          money: MoneyProxy.new(123_45, :USD),
          from: acc_a,
          to: acc_b,
          code: :deposit
        })

      assert {:ok, %Transfer{}} = transfer
      assert Line |> ExDoubleEntry.repo().all() |> Enum.count() == 2
    end

    test "failure", %{acc_a: acc_a, acc_b: acc_b} do
      transfer =
        Reversal.perform!(%Transfer{
          money: MoneyProxy.new(123_45, :USD),
          from: acc_a,
          to: acc_b,
          code: :give_away
        })

      assert {:error, :undefined_transfer_code, "Transfer code :give_away is undefined."} =
               transfer

      assert Line |> ExDoubleEntry.repo().all() |> Enum.count() == 0
    end
  end
end
