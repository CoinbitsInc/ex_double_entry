defmodule ExDoubleEntry.TransferTest do
  use ExDoubleEntry.DataCase
  alias ExDoubleEntry.{Account, AccountBalance, Line, MoneyProxy, Transfer}
  doctest Transfer

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
        Transfer.perform!(
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
        Transfer.perform!(%Transfer{
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
        Transfer.perform!(%Transfer{
          money: MoneyProxy.new(123_45, :USD),
          from: acc_a,
          to: acc_b,
          code: :give_away
        })

      assert {:error, :undefined_transfer_code, "Transfer code :give_away is undefined."} =
               transfer

      assert Line |> ExDoubleEntry.repo().all() |> Enum.count() == 0
    end

    test "handles positive only account flag", %{acc_a: acc_a, acc_b: acc_b} do
      uuid = Ecto.UUID.generate()

      assert {:error, :insufficient_balance,
              "Transfer: USD 30000, from :savings (balance amount: 20000) to :checking"} =
               Transfer.perform!(%Transfer{
                 money: MoneyProxy.new(30000, :USD),
                 from: acc_b,
                 to: acc_a,
                 code: :withdraw,
                 idempotence: uuid
               })
    end

    test "idempotence", %{acc_a: acc_a, acc_b: acc_b} do
      uuid = Ecto.UUID.generate()

      assert {:ok, _transfer} =
               Transfer.perform!(%Transfer{
                 money: MoneyProxy.new(123_45, :USD),
                 from: acc_b,
                 to: acc_a,
                 code: :withdraw,
                 idempotence: uuid
               })

      assert {:error, :non_idempotent_transfer, _} =
               Transfer.perform!(%Transfer{
                 money: MoneyProxy.new(123_45, :USD),
                 from: acc_b,
                 to: acc_a,
                 code: :withdraw,
                 idempotence: uuid
               })
    end
  end

  test "perform/1", %{acc_a: acc_a, acc_b: acc_b} do
    Transfer.perform(%Transfer{
      money: MoneyProxy.new(123_45, :USD),
      from: acc_a,
      to: acc_b,
      code: :deposit,
      metadata: %{diamond: "hands"}
    })

    [line1, line2] = ExDoubleEntry.repo().all(Line)
    [line1_id, line2_id] = [line1.id, line2.id]
    [acc_a_id, acc_b_id] = [acc_a.id, acc_b.id]

    amount = Decimal.new(123_45)
    amount_neg = Decimal.new(-123_45)
    balance1 = Decimal.new(76_55)
    balance2 = Decimal.new(323_45)

    assert %AccountBalance{
             balance_amount: ^balance1
           } = AccountBalance.for_account(acc_a)

    assert %AccountBalance{
             balance_amount: ^balance2
           } = AccountBalance.for_account(acc_b)

    assert %Line{
             account_identifier: :checking,
             account_scope: nil,
             currency: :USD,
             amount: ^amount_neg,
             balance_amount: ^balance1,
             code: :deposit,
             partner_identifier: :savings,
             partner_scope: nil,
             partner_line_id: ^line2_id,
             account_balance_id: ^acc_a_id,
             metadata: %{"diamond" => "hands"}
           } = line1

    assert %Line{
             account_identifier: :savings,
             account_scope: nil,
             currency: :USD,
             amount: ^amount,
             balance_amount: ^balance2,
             code: :deposit,
             partner_identifier: :checking,
             partner_scope: nil,
             partner_line_id: ^line1_id,
             account_balance_id: ^acc_b_id,
             metadata: %{"diamond" => "hands"}
           } = line2
  end
end
