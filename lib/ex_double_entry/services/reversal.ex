defmodule ExDoubleEntry.Reversal do
  alias ExDoubleEntry.Transfer

  def perform!(%Transfer{from: from, to: to, code: code} = transfer) do
    %Transfer{transfer | from: to, to: from, code: :"#{code}_reversal"}
    |> Transfer.perform!(ensure_accounts: false)
  end

  def perform!(transfer_attrs) do
    Transfer |> struct(transfer_attrs) |> perform!()
  end
end
