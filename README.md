# ExDoubleEntry

[![Build Status](https://github.com/coinjar/ex_double_entry/actions/workflows/ci.yml/badge.svg)](https://github.com/coinjar/ex_double_entry/actions)

An Elixir double-entry library inspired by Ruby's [DoubleEntry](https://github.com/envato/double_entry).

![](https://i.imgur.com/QqrlYZ9.png)

## Supported Databases

- Postgres 9.4+ (for `JSONB` support)
- MySQL 8.0+ (for row locking support)

## Installation

```elixir
def deps do
  [
    {:ex_double_entry, github: "CoinbitsInc/ex_double_entry"},
    # pick one DB package
    {:postgrex, ">= 0.0.0"},
    {:myxql, ">= 0.0.0"},
    # pick one money package
    {:money, "~> 1.9"},
    {:ex_money, "~> 5.9"},
  ]
end
```

### DB Migration

You will need to copy and run the [migration file](priv/repo/migrations/001_ex_double_entry_tables.exs) to create the DB tables.

## Configuration

```elixir
config :ex_double_entry,
  db: :postgres,
  db_table_prefix: "ex_double_entry_",
  # we can customise the DB schema for postgres
  db_schema: "public",
  repo: YourProject.Repo,
  default_currency: :USD,
  # all accounts need to be defined here
  accounts: %{
    # account identifier: account options
    #
    # valid options are:
    #   "positive_only": whether the account can go into negative balance
    bank: [],
    savings: [positive_only: true],
    checking: [],
  },
  # all transfers need to be defined here
  transfers: %{
    # transfer code: transfer pairs
    #
    # for each transfer pair:
    #   - the first element is the source account
    #   - the second element is the destination account
    #   - an optional third element to specify whether the transfer is reversible
    deposit: [
      {:bank, :savings},
      {:bank, :checking},
      {:checking, :savings, reversible: true},
    ],
    withdraw: [
      {:savings, :checking},
    ],
  }
```

## Usage

### Accounts & Balances

```elixir
# creates a new account with 0 balance
ExDoubleEntry.make_account!(
  # identifier of the account, in atom
  :savings,
  # currency can be any arbitrary atom
  currency: :USD,
  # optional, scope can be any arbitrary string
  #
  # due to DB index on `NULL` values, scope value can only be `nil` (stored as
  # an empty string in the DB) or non-empty strings
  scope: "user/1",
  # optional, as a map, default is `nil`, useful for capturing account related
  # data such as an external ID
  metadata: %{"id" => "ABC-XYZ"}
)

# looks up an account with its balance
ExDoubleEntry.lookup_account!(
  :savings,
  currency: :USD,
  scope: "user/1"
)
```

Both functions return an `ExDoubleEntry.Account` struct that looks like this:

```elixir
%ExDoubleEntry.Account{
  id: 1,
  identifier: :savings,
  currency: :USD,
  scope: "user/1",
  positive_only?: true,
  balance: Money.new(0, :USD),
  metadata: %{"id" => "ABC-XYZ"}
}
```

### Transfers

There are two transfer modes, `transfer` and `transfer!`.

Note: ExDoubleEntry relies on either the
[money](https://github.com/elixirmoney/money) or
[ex_money](https://github.com/kipcole9/money) library for balances and amounts.

`money` and `ex_money` uses different notations for amounts, `money` only
supports integer values to represents the smallest unit of the currency (e.g.
cents), whereas `ex_money` can use string or decimal values to represent the
money value.

ExDoubleEntry uses decimal to store the values in the database, however it does
not convert the values, so for `ex_money`, what you can is what you get, but for
`money` the stored decimal values are all integers.

So, for the amount `100.23` USD, `money` stores it as `10023` whereas `ex_money`
stores it as `100.23`.

```elixir
# accounts need to exist in the DB otherwise
# `ExDoubleEntry.Account.NotFoundError` is raised
ExDoubleEntry.transfer(
  money: Money.new(100_00, :USD),
  # accounts need to be defined in the config
  from: account_a,
  to: account_b,
  # transfer code is required, and must be defined in the config
  code: :deposit,
  # optional, metadata can be any arbitrary map, it gets stored in the DB
  # as either a JSON string (MySQL) or a JSONB object (Postgres)
  metadata: %{diamond: "hands"},
  # optional, a UUID can be used as the idempotence key to ensure the same
  # transfer is not repeated multiple times
  idempotence: "08eaa008-2d1c-4c20-b1c4-ed79065a0d6c"
)
# => {:ok, %ExDoubleEntry.Transfer{...}}

# accounts will be created in the DB if they don't exist
# once accounts are created they will be locked during the transfer
ExDoubleEntry.transfer!(
  money: Money.new(100_00, :USD),
  from: account_a,
  to: account_b,
  code: :deposit
)
# => {:ok, %ExDoubleEntry.Transfer{...}}

# it can be performed on the `Transfer` struct too
%ExDoubleEntry.Transfer{
  money: Money.new(100_00, :USD),
  from: account_a,
  to: account_b,
  code: :deposit
}
|> ExDoubleEntry.transfer!()
```

In both modes, a tuple of containing the `%ExDoubleEntry.Transfer{}` struct gets
returned.

### Reversals

A reversal is intended to be used when a transfer has occurred, then later on it
needs to be reversed. Therefore, a reversal only works when the accounts exist
(i.e. the reversal will fail if either account doesn't exist).

A reversal is only permitted when the transfer is configured for it, see the
[Configuration](#configuration) section. A reversal's line items will be created
using the `:"#{code}_reversal"` transfer code, e.g. `:deposit` becomes
`:deposit_reversal`.

The `from` and `to` needs to be specified in the transfer's original order. For
instance, to reverse a transfer that was a deposit from `account_a` to
`account_b`, the `from` and `to` remains as `from: account_a` and
`to: account_b`.

Bear in mind that a reversal is a convenience function, it is performed
independently to the original transfer and does not have any link to the
original transfer.

```elixir
ExDoubleEntry.reverse(
  money: Money.new(100_00, :USD),
  from: account_a,
  to: account_b,
  code: :deposit
)
# => {:ok, %ExDoubleEntry.Transfer{...}}

%ExDoubleEntry.Transfer{
  money: Money.new(100_00, :USD),
  from: account_a,
  to: account_b,
  code: :deposit
}
|> ExDoubleEntry.reverse()
# => {:ok, %ExDoubleEntry.Transfer{...}}
```

### Locking

Transfer itself will already lock the accounts involved. However, if there are
other tasks that need to be performed atomically with the transfer, you can
perform them using `lock_accounts`.

Transactions can be nested arbitrarily, since in Ecto, transactions are
flattened and are committed or rolled back based on the outer most transaction.

Read more on Ecto's transaction handling [here](https://hexdocs.pm/ecto/Ecto.Repo.html#c:transaction/2).

```elixir
ExDoubleEntry.lock_accounts([account_a, account_b], fn ->
  ExDoubleEntry.transfer!(
    money: Money.new(100, :USD),
    from: account_a,
    to: account_b,
    code: :deposit
  )

  # perform other tasks that should be committed atomically with the transfer
end)
```

## License

Licensed under [MIT](LICENSE.md).

## Sponsors

- [CoinJar](https://coinjar.com)
- [Coinbits](https://coinbits.com)
