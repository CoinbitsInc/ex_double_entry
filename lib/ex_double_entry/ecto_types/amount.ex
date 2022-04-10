if Code.ensure_loaded?(Ecto.Type) do
  defmodule ExDoubleEntry.EctoType.Amount do
    if macro_exported?(Ecto.Type, :__using__, 1) do
      use Ecto.Type
    else
      @behaviour Ecto.Type
    end

    def type, do: :decimal

    def cast(val) when is_binary(val), do: {:ok, Decimal.new(val)}
    def cast(val) when is_integer(val), do: {:ok, Decimal.new(val)}
    def cast(val) when is_float(val), do: {:ok, Decimal.from_float(val)}
    def cast(%Decimal{} = val), do: {:ok, val}
    def cast(_), do: :error

    def load(%Decimal{} = val), do: {:ok, val}

    def dump(val), do: cast(val)
  end
end
