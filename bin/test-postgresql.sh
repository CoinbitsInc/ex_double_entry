#!/usr/bin/env sh

set -e

MIX_ENV=test_ex_money mix test
MIX_ENV=test_ex_money_stress mix test --only stress_test
MIX_ENV=test_money mix test
