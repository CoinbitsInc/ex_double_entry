defmodule ExDoubleEntry.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import ExDoubleEntry.DataCase
      import ExDoubleEntry.Factory
    end
  end

  setup tags do
    if tags[:stress_test] do
      on_exit(&truncate_tables/0)
    else
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(ExDoubleEntry.repo())

      unless tags[:async] do
        Ecto.Adapters.SQL.Sandbox.mode(ExDoubleEntry.repo(), {:shared, self()})
      end
    end

    :ok
  end

  def truncate_tables do
    Enum.each([:account_balances, :lines], fn name ->
      table = "#{ExDoubleEntry.db_table_prefix()}#{name}"
      ExDoubleEntry.repo() |> Ecto.Adapters.SQL.query("TRUNCATE #{table} CASCADE")
    end)
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
