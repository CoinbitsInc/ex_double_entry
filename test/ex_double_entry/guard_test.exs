defmodule ExDoubleEntry.GuardTest do
  use ExDoubleEntry.DataCase
  alias ExDoubleEntry.{Account, Guard, MoneyProxy, Transfer}
  doctest Guard

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

  describe "idempotent_if_provided?" do
    test "nil", %{acc_a: acc_a, acc_b: acc_b} do
      Transfer.perform!(
        money: MoneyProxy.new(123_45, :USD),
        from: acc_a,
        to: acc_b,
        code: :deposit
      )

      assert {:ok, _transfer} =
               Guard.idempotent_if_provided?(%Transfer{
                 money: MoneyProxy.new(123_45, :USD),
                 from: acc_a,
                 to: acc_b,
                 code: :deposit
               })
    end

    test "ok", %{acc_a: acc_a, acc_b: acc_b} do
      Transfer.perform!(
        money: MoneyProxy.new(123_45, :USD),
        from: acc_a,
        to: acc_b,
        code: :deposit,
        idempotence: Ecto.UUID.generate()
      )

      assert {:ok, _transfer} =
               Guard.idempotent_if_provided?(%Transfer{
                 money: MoneyProxy.new(123_45, :USD),
                 from: acc_a,
                 to: acc_b,
                 code: :deposit,
                 idempotence: Ecto.UUID.generate()
               })
    end

    test "error", %{acc_a: acc_a, acc_b: acc_b} do
      uuid = Ecto.UUID.generate()

      Transfer.perform!(
        money: MoneyProxy.new(123_45, :USD),
        from: acc_a,
        to: acc_b,
        code: :deposit,
        idempotence: uuid
      )

      assert {:error, :non_idempotent_transfer, _} =
               Guard.idempotent_if_provided?(%Transfer{
                 money: MoneyProxy.new(123_45, :USD),
                 from: acc_a,
                 to: acc_b,
                 code: :deposit,
                 idempotence: uuid
               })
    end
  end
end
