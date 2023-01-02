defmodule ExDoubleEntry.TransferStressTest do
  use ExDoubleEntry.DataCase, async: false

  alias ExDoubleEntry.Account
  alias ExDoubleEntry.AccountBalance
  alias ExDoubleEntry.Line
  alias ExDoubleEntry.MoneyProxy
  alias ExDoubleEntry.Transfer

  @moduletag stress_test: true

  @stress_test_transfers_count 1_000

  setup do
    credit_account =
      :account_balance
      |> insert(
        balance_amount: @stress_test_transfers_count,
        identifier: :credit,
        scope: to_string(__MODULE__)
      )
      |> Account.present()

    checking_account =
      :account_balance
      |> insert(
        balance_amount: 0,
        identifier: :checking,
        scope: to_string(__MODULE__)
      )
      |> Account.present()

    assert credit_account.positive_only?
    refute checking_account.positive_only?

    pool_size =
      :ex_double_entry
      |> Application.get_env(ExDoubleEntry.Repo)
      |> Keyword.get(:pool_size)

    [
      credit_account: credit_account,
      checking_account: checking_account,
      pool_size: pool_size
    ]
  end

  describe "perform/1" do
    test "guarantees 'positive only' guard on concurrent transactions", %{
      credit_account: credit_account,
      checking_account: checking_account
    } do
      assert [
               {:ok, %Transfer{}},
               {:error, :insufficient_balance,
                "Transfer: USD 1000, from :credit (balance amount: 0) to :checking"},
               {:error, :insufficient_balance,
                "Transfer: USD 1000, from :credit (balance amount: 0) to :checking"}
             ] =
               Enum.map(1..3, fn _ ->
                 Task.async(fn ->
                   Transfer.perform(%Transfer{
                     code: :transfer,
                     from: credit_account,
                     money: MoneyProxy.new(@stress_test_transfers_count, :USD),
                     to: checking_account
                   })
                 end)
               end)
               |> Task.await_many()
               |> Enum.sort()
    end

    test "guarantees idempotency on concurrent transactions", %{
      credit_account: credit_account,
      checking_account: checking_account
    } do
      assert [
               {:ok, %Transfer{}},
               {:error, :non_idempotent_transfer,
                "Transfer is not idempotent: 01c8d79b-d7c8-412d-a1e5-f6f7cfde9ebc."},
               {:error, :non_idempotent_transfer,
                "Transfer is not idempotent: 01c8d79b-d7c8-412d-a1e5-f6f7cfde9ebc."}
             ] =
               Enum.map(1..3, fn _ ->
                 Task.async(fn ->
                   Transfer.perform(%Transfer{
                     code: :transfer,
                     from: credit_account,
                     idempotence: "01c8d79b-d7c8-412d-a1e5-f6f7cfde9ebc",
                     money: MoneyProxy.new(1, :USD),
                     to: checking_account
                   })
                 end)
               end)
               |> Task.await_many()
               |> Enum.sort()
    end

    test "guarantees balance consistency on concurrent transactions", %{
      credit_account: credit_account,
      checking_account: checking_account,
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
                       from: credit_account,
                       money: MoneyProxy.new(1, :USD),
                       to: checking_account
                     })
          end)
        end)
        |> Task.await_many()

        IO.write(".")
      end)

      assert %AccountBalance{
               balance_amount: credit_account_balance_amount,
               id: credit_account_balance_id
             } = AccountBalance.for_account(credit_account)

      assert %AccountBalance{
               balance_amount: checking_account_balance_amount,
               id: checking_account_balance_id
             } = AccountBalance.for_account(checking_account)

      assert Decimal.equal?(credit_account_balance_amount, Decimal.new(0))

      assert Decimal.equal?(
               checking_account_balance_amount,
               Decimal.new(@stress_test_transfers_count)
             )

      lines = ExDoubleEntry.repo().all(Line)

      assert Enum.to_list(0..(@stress_test_transfers_count - 1)) ==
               lines
               |> Stream.filter(&(&1.account_balance_id == credit_account_balance_id))
               |> Stream.map(& &1.balance_amount)
               |> Stream.map(&Decimal.to_integer/1)
               |> Enum.sort()

      assert Enum.to_list(1..@stress_test_transfers_count) ==
               lines
               |> Stream.filter(&(&1.account_balance_id == checking_account_balance_id))
               |> Stream.map(& &1.balance_amount)
               |> Stream.map(&Decimal.to_integer/1)
               |> Enum.sort()
    end
  end
end
