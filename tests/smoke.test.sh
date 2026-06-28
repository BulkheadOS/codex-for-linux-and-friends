#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

help_output="$(bin/codex-linux --help)"
case "$help_output" in
  *"Codex for Linux and friends"* ) ;;
  * ) echo "help output did not include product name" >&2; exit 1 ;;
esac

status_output="$(CODEX_LINUX_INSTALL_DIR="$(mktemp -d)/missing" bin/codex-linux status)"
case "$status_output" in
  *"Not installed."* ) ;;
  * ) echo "status output should report a missing install" >&2; exit 1 ;;
esac

json_output="$(CODEX_LINUX_INSTALL_DIR="$(mktemp -d)/missing" bin/codex-linux status --json)"
node -e 'const value = JSON.parse(process.argv[1]); if (value.installed !== false) process.exit(1)' "$json_output"

if grep -q 'exec "$SCRIPT_DIR/electron"' bin/codex-linux; then
  echo "launcher must not exec electron after starting the webview server; cleanup trap would be skipped" >&2
  exit 1
fi

if grep -q 'exec >>"$LAUNCHER_LOG_FILE"' bin/codex-linux; then
  echo "launcher must not persist raw Electron stdout/stderr by default" >&2
  exit 1
fi
