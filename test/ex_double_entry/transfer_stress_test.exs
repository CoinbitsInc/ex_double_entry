defmodule ExDoubleEntry.TransferStressTest do
  use ExDoubleEntry.DataCase, async: false
  alias ExDoubleEntry.{Account, AccountBalance, Line, MoneyProxy, Transfer}
  doctest Transfer

  @moduletag stress_test: true

  @stress_test_transfers_count 1_000

  setup do
    acc_a =
      :account_balance
      |> insert(
        balance_amount: @stress_test_transfers_count,
        identifier: :checking,
        scope: to_string(__MODULE__)
      )
      |> Account.present()

    acc_b =
      :account_balance
      |> insert(
        balance_amount: 0,
        identifier: :savings,
        scope: to_string(__MODULE__)
      )
      |> Account.present()

    pool_size =
      :ex_double_entry
      |> Application.get_env(ExDoubleEntry.Repo)
      |> Keyword.get(:pool_size)

    [
      acc_a: acc_a,
      acc_b: acc_b,
      pool_size: pool_size
    ]
  end

  describe "perform/1" do
    test "guarantees consistency on concurrent transactions", %{
      acc_a: acc_a,
      acc_b: acc_b,
      pool_size: pool_size
    } do
      1..@stress_test_transfers_count
      |> Enum.chunk_every(pool_size)
      |> Enum.each(fn group ->
        Enum.map(group, fn _ ->
          Task.async(fn ->
            assert {:ok, %Transfer{}} =
                     Transfer.perform(%Transfer{
                       code: :transfer,
                       from: acc_a,
                       money: MoneyProxy.new(1, :USD),
                       to: acc_b
                     })
          end)
        end)
        |> Task.await_many()

        IO.write(".")
      end)

      assert %AccountBalance{
               balance_amount: acc_a_balance_amount,
               id: acc_a_balance_id
             } = AccountBalance.for_account(acc_a)

      assert %AccountBalance{
               balance_amount: acc_b_balance_amount,
               id: acc_b_balance_id
             } = AccountBalance.for_account(acc_b)

      assert Decimal.equal?(acc_a_balance_amount, Decimal.new(0))
      assert Decimal.equal?(acc_b_balance_amount, Decimal.new(@stress_test_transfers_count))

      lines = ExDoubleEntry.repo().all(Line)

      assert Enum.to_list(0..(@stress_test_transfers_count - 1)) ==
               lines
               |> Stream.filter(&(&1.account_balance_id == acc_a_balance_id))
               |> Stream.map(& &1.balance_amount)
               |> Stream.map(&Decimal.to_integer/1)
               |> Enum.sort()

      assert Enum.to_list(1..@stress_test_transfers_count) ==
               lines
               |> Stream.filter(&(&1.account_balance_id == acc_b_balance_id))
               |> Stream.map(& &1.balance_amount)
               |> Stream.map(&Decimal.to_integer/1)
               |> Enum.sort()
    end
  end
end
