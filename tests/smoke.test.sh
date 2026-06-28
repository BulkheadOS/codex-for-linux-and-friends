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

if ! grep -q 'CODEX_LINUX_CXX' bin/codex-linux; then
  echo "native rebuild should allow an explicit C++ compiler override" >&2
  exit 1
fi

if ! grep -q 'npm_config_cxx="$native_cxx"' bin/codex-linux; then
  echo "native rebuild should pass the selected C++ compiler into node-gyp" >&2
  exit 1
fi

if grep -q 'for cmd in curl node npm npx python3 unzip make g++' bin/codex-linux; then
  echo "doctor should not require g++ before honoring CODEX_LINUX_CXX" >&2
  exit 1
fi

if grep -q 'Refused to start webview server' bin/codex-linux; then
  echo "launcher should not fail just because another Codex compatibility launcher owns the webview port" >&2
  exit 1
fi

if ! grep -q 'readlink -f "$resolved"' bin/codex-linux; then
  echo "compiler overrides resolved from PATH should become absolute before native rebuild" >&2
  exit 1
fi

if ! grep -q 'unset ELECTRON_RUN_AS_NODE' bin/codex-linux; then
  echo "launcher must clear ELECTRON_RUN_AS_NODE before starting Electron" >&2
  exit 1
fi

if ! grep -q -- '--startup-background: #1e1e1e' bin/codex-linux; then
  echo "installer should apply the known Linux webview startup-background patch" >&2
  exit 1
fi

if ! grep -q 'MimeType=x-scheme-handler/codex;' templates/codex-for-linux.desktop.in; then
  echo "desktop launcher should register codex: deep links like the working community launcher" >&2
  exit 1
fi

if ! grep -q 'update-desktop-database "$(dirname "$DESKTOP_FILE_PATH")"' bin/codex-linux; then
  echo "desktop install should refresh the desktop MIME database when available" >&2
  exit 1
fi

if ! grep -q 'xdg-mime default "$(basename "$DESKTOP_FILE_PATH")" x-scheme-handler/codex' bin/codex-linux; then
  echo "desktop install should register codex: links to the installed launcher when xdg-mime is available" >&2
  exit 1
fi
