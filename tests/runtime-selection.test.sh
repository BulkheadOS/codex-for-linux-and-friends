#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_DIR="$(mktemp -d)"

cleanup() {
  rm -rf "$TEMP_DIR"
}

trap cleanup EXIT

source_without_main() {
  sed '$d' "$ROOT/bin/codex-linux"
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  local label="$3"

  if [ "$expected" != "$actual" ]; then
    printf 'FAIL: %s\nExpected: %s\nActual:   %s\n' "$label" "$expected" "$actual" >&2
    exit 1
  fi
}

(
  CODEX_LINUX_PROJECT_DIR="$ROOT"
  source <(source_without_main)

  mkdir -p "$TEMP_DIR/app"
  cat >"$TEMP_DIR/app/package.json" <<'JSON'
{
  "name": "codex-desktop",
  "devDependencies": {
    "electron": "^42.1.0"
  }
}
JSON

  assert_eq "42.1.0" "$(detect_electron_version "$TEMP_DIR/app")" "detects Electron from app package.json"

  CODEX_ELECTRON_VERSION="41.2.3"
  assert_eq "41.2.3" "$(detect_electron_version "$TEMP_DIR/app")" "honors explicit Electron override"
  unset CODEX_ELECTRON_VERSION

  assert_eq "12.11.1" "$(resolve_better_sqlite3_version "12.9.0" "42.1.0")" "upgrades better-sqlite3 for Electron 42"
  assert_eq "12.11.1" "$(resolve_better_sqlite3_version "12.11.1" "42.1.0")" "keeps compatible better-sqlite3 floor"
  assert_eq "12.9.0" "$(resolve_better_sqlite3_version "12.9.0" "40.0.0")" "keeps older Electron builds unchanged"

  CODEX_BETTER_SQLITE3_VERSION="12.10.1"
  assert_eq "12.10.1" "$(resolve_better_sqlite3_version "12.9.0" "42.1.0")" "honors explicit better-sqlite3 override"
  unset CODEX_BETTER_SQLITE3_VERSION

  mkdir -p "$TEMP_DIR/bin"
  touch "$TEMP_DIR/bin/test-g++"
  chmod +x "$TEMP_DIR/bin/test-g++"
  PATH="$TEMP_DIR/bin:$PATH"
  assert_eq "$(readlink -f "$TEMP_DIR/bin/test-g++")" "$(resolve_host_compiler CODEX_LINUX_CXX test-g++ g++)" "PATH compiler override resolves to an absolute path"
)

printf 'runtime-selection tests passed\n'
