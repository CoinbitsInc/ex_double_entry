#!/usr/bin/env sh

set -e

MIX_ENV=test_ex_money mix test
MIX_ENV=test_ex_money_concurrent_db_pool mix test
MIX_ENV=test_money mix test
