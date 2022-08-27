defmodule ExDoubleEntry.LineTest do
  use ExDoubleEntry.DataCase
  alias ExDoubleEntry.{Account, Line, MoneyProxy}
  doctest Line

  setup do
    acc_a = :account_balance |> insert(identifier: :checking) |> Account.present()
    acc_b = :account_balance |> insert(identifier: :savings) |> Account.present()

    [acc_a: acc_a, acc_b: acc_b]
  end

  test "insert/2", %{acc_a: acc_a, acc_b: acc_b} do
    acc_a_id = acc_a.id
    uuid = Ecto.UUID.generate()

    line =
      Line.insert!(
        MoneyProxy.new(100, :USD),
        account: acc_a,
        partner: acc_b,
        code: :deposit,
        metadata: %{diamond: "hands"},
        idempotence: uuid
      )

    amount = Decimal.new(100)

    assert %Line{
             account_identifier: :checking,
             currency: :USD,
             code: :deposit,
             amount: ^amount,
             balance_amount: ^amount,
             partner_identifier: :savings,
             metadata: %{diamond: "hands"},
             idempotence: ^uuid,
             account_balance_id: ^acc_a_id
           } = line
  end

  test "insert/2 string", %{acc_a: acc_a, acc_b: acc_b} do
    if ExDoubleEntry.MoneyProxy.is_ex_money?() do
      acc_a_id = acc_a.id

      line =
        Line.insert!(
          MoneyProxy.new("100.23", :USD),
          account: acc_a,
          partner: acc_b,
          code: :deposit,
          metadata: %{diamond: "hands"}
        )

      amount = Decimal.new("100.23")

      assert %Line{
               account_identifier: :checking,
               currency: :USD,
               code: :deposit,
               amount: ^amount,
               balance_amount: ^amount,
               partner_identifier: :savings,
               metadata: %{diamond: "hands"},
               account_balance_id: ^acc_a_id
             } = line
    end
  end
end
