defmodule ExDoubleEntry.AccountBalanceTest do
  use ExDoubleEntry.DataCase
  alias ExDoubleEntry.{Account, AccountBalance, MoneyProxy, Transfer}
  doctest AccountBalance

  test "create!/1 - balance will always be 0" do
    account = %Account{
      identifier: :savings,
      scope: "user/1",
      currency: :USD,
      balance: MoneyProxy.new(42, :USD),
      metadata: %{"hello" => "world"}
    }

    amount = Decimal.new(0)

    assert %AccountBalance{
             balance_amount: ^amount,
             metadata: %{"hello" => "world"}
           } = AccountBalance.create!(account)

    assert_raise(Ecto.InvalidChangesetError, fn ->
      AccountBalance.create!(account)
    end)
  end

  describe "for_account/1" do
    setup do
      insert(:account_balance,
        identifier: :savings,
        currency: :USD,
        scope: "user/1",
        balance_amount: 42
      )

      insert(:account_balance, identifier: :savings, currency: :USD, balance_amount: 24)
      insert(:account_balance, identifier: :savings, currency: :AUD, balance_amount: 1337)
      insert(:account_balance, identifier: :checking, currency: :AUD, balance_amount: 233)

      :ok
    end

    test "a" do
      ab =
        AccountBalance.for_account(%Account{
          identifier: :savings,
          currency: :USD,
          scope: "user/1"
        })

      amount = Decimal.new(42)

      assert %AccountBalance{
               identifier: :savings,
               currency: :USD,
               scope: "user/1",
               balance_amount: ^amount,
               metadata: nil
             } = ab
    end

    test "b" do
      ab =
        AccountBalance.for_account(%Account{
          identifier: :savings,
          currency: :AUD
        })

      amount = Decimal.new(1337)

      assert %AccountBalance{
               identifier: :savings,
               currency: :AUD,
               scope: nil,
               balance_amount: ^amount
             } = ab
    end

    test "c" do
      ab =
        AccountBalance.for_account(%Account{
          identifier: :checking,
          currency: :AUD
        })

      amount = Decimal.new(233)

      assert %AccountBalance{
               identifier: :checking,
               currency: :AUD,
               scope: nil,
               balance_amount: ^amount
             } = ab
    end
  end

  test "for_account!/1" do
    ab =
      AccountBalance.for_account!(%Account{
        identifier: :crypto,
        currency: :BTC
      })

    amount = Decimal.new(0)

    assert %AccountBalance{
             identifier: :crypto,
             currency: :BTC,
             scope: nil,
             balance_amount: ^amount,
             metadata: nil
           } = ab
  end

  describe "lock_multi!/2" do
    setup do
      acc_a = :account_balance |> insert(identifier: :checking) |> Account.present()
      acc_b = :account_balance |> insert(identifier: :savings) |> Account.present()

      [acc_a: acc_a, acc_b: acc_b]
    end

    test "multiple locks", %{acc_a: acc_a, acc_b: acc_b} do
      tasks =
        for i <- 0..4 do
          Task.async(fn ->
            AccountBalance.lock_multi!([acc_a, acc_b], fn _ -> i end)
          end)
        end
        |> Task.await_many()

      assert Enum.reduce(tasks, 0, fn {:ok, n}, acc -> acc + n end) == 10
    end

    test "failed locks", %{acc_a: acc_a, acc_b: acc_b} do
      [
        Task.async(fn ->
          AccountBalance.lock_multi!([acc_a, acc_b], fn _ -> :timer.sleep(1600) end)
        end),
        Task.async(fn ->
          assert_raise(DBConnection.ConnectionError, fn ->
            AccountBalance.lock_multi!([acc_a, acc_b], fn _ ->
              Transfer.perform(%Transfer{
                money: MoneyProxy.new(42, :USD),
                from: acc_a,
                to: acc_b,
                code: :deposit,
                metadata: nil
              })
            end)
          end)
        end)
      ]
      |> Task.await_many()
    end
  end

  describe "locked?/1" do
    setup do
      acc_a = :account_balance |> insert(identifier: :credit) |> Account.present()
      acc_b = :account_balance |> insert(identifier: :checking) |> Account.present()

      [accounts: [acc_a, acc_b]]
    end

    @tag concurrent_db_pool: true
    test "returns false when is not locked", %{accounts: accounts} do
      refute AccountBalance.locked?(accounts)
      refute AccountBalance.locked?(hd(accounts))
    end

    @tag concurrent_db_pool: true
    test "returns true when any given account is locked", %{accounts: [acc_a, acc_b]} do
      {:ok, pid} =
        Task.start_link(fn ->
          receive do
            :lock ->
              AccountBalance.lock_multi!([acc_a], fn _accounts ->
                receive do
                  :unlock -> :ok
                end
              end)
          end
        end)

      send(pid, :lock)

      # Let the child process create a lock:
      :timer.sleep(20)

      assert AccountBalance.locked?(acc_a)
      assert AccountBalance.locked?([acc_b, acc_a])

      send(pid, :unlock)

      refute AccountBalance.locked?(acc_b)
      refute AccountBalance.locked?([acc_b, acc_a])
    end
  end
end
