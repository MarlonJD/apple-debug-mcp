#!/bin/sh
set -eu

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"

./scripts/check.sh

python3 ./scripts/harness_contract.py

printf '%s\n' 'harness-check: project-native build, test, smoke, and repository authority checks passed'
