#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

sed \
  -e "s|__EXEC__|/usr/bin/codex-for-linux|g" \
  -e "s|__ICON__|/usr/share/icons/hicolor/512x512/apps/com.bulkheados.CodexForLinux.png|g" \
  templates/codex-for-linux.desktop.in >"$tmp/codex-for-linux.desktop"

desktop-file-validate "$tmp/codex-for-linux.desktop"
desktop-file-validate packaging/flatpak/com.bulkheados.CodexForLinux.desktop

if ! grep -q '^Exec=.*%u' "$tmp/codex-for-linux.desktop"; then
  echo "generated desktop entry must pass registered codex: URLs to the launcher" >&2
  exit 1
fi

if ! grep -q '^Exec=.*%u' packaging/flatpak/com.bulkheados.CodexForLinux.desktop; then
  echo "Flatpak desktop entry must pass registered codex: URLs to the launcher" >&2
  exit 1
fi
