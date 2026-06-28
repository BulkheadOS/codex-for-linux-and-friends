#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

node --test tests/*.test.mjs
bash tests/smoke.test.sh
bash tests/desktop.test.sh
bash scripts/qa-public-safety.sh
