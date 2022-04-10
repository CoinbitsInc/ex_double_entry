defmodule ExDoubleEntry.MoneyProxy do
  @moduledoc """
  The `Money` and `ExMoney` packages both claim the `Money` module namespace,
  therefore this proxy module normalises the function uses so that ExDoubleEntry
  can be used by either.
  """

  require Decimal

  def is_ex_money? do
    function_exported?(Money, :to_string!, 2)
  end

  def is_money? do
    !is_ex_money?()
  end

  defdelegate positive?(money), to: Money

  def new(amount, currency) do
    if is_ex_money?() do
      apply(Money, :new, [amount, currency])
    else
      amount =
        if Decimal.is_decimal(amount) do
          Decimal.to_integer(amount)
        else
          amount
        end

      apply(Money, :new, [amount, currency])
    end
  end

  def add(a, b) do
    if is_ex_money?() do
      apply(Money, :add!, [a, b])
    else
      apply(Money, :add, [a, b])
    end
  end

  def subtract(a, b) do
    if is_ex_money?() do
      apply(Money, :sub!, [a, b])
    else
      apply(Money, :subtract, [a, b])
    end
  end

  def cmp(a, b) do
    if is_ex_money?() do
      apply(Money, :compare!, [a, b])
    else
      apply(Money, :cmp, [a, b])
    end
  end

  def neg(money) do
    if is_ex_money?() do
      apply(Money, :mult!, [money, -1])
    else
      apply(Money, :neg, [money])
    end
  end
end
