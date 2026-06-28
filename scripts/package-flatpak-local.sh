#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_DIR="${CODEX_LINUX_INSTALL_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/codex-for-linux/runtime}"
DIST_DIR="${CODEX_LINUX_FLATPAK_DIST:-$PROJECT_DIR/dist/flatpak}"
BUILD_DIR="$DIST_DIR/build"
REPO_DIR="$DIST_DIR/repo"
BUNDLE_PATH="$DIST_DIR/codex-for-linux.flatpak"
MANIFEST="$PROJECT_DIR/packaging/flatpak/com.bulkheados.CodexForLinux.yml"
RUNTIME_COPY="$DIST_DIR/runtime"

usage() {
  cat <<'EOF'
Usage: scripts/package-flatpak-local.sh

Build a local Flatpak bundle from an already generated Codex for Linux runtime.
This is for personal/local installation only. Do not upload the generated bundle
unless you have rights to redistribute the upstream app contents.
The local manifest grants home-directory access so Codex can open the projects
you choose.

Environment:
  CODEX_LINUX_INSTALL_DIR       Existing runtime directory to package.
  CODEX_LINUX_FLATPAK_DIST     Output directory, default ./dist/flatpak.
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  usage
  exit 0
fi

command -v flatpak-builder >/dev/null 2>&1 || {
  echo "flatpak-builder is required. Install it with your distro package manager." >&2
  exit 1
}

command -v flatpak >/dev/null 2>&1 || {
  echo "flatpak is required. Install it with your distro package manager." >&2
  exit 1
}

if [ ! -x "$INSTALL_DIR/start.sh" ]; then
  echo "Runtime not found at $INSTALL_DIR." >&2
  echo "Run: bin/codex-linux install" >&2
  exit 1
fi

rm -rf "$BUILD_DIR" "$RUNTIME_COPY"
mkdir -p "$DIST_DIR" "$REPO_DIR"
cp -a "$INSTALL_DIR" "$RUNTIME_COPY"

flatpak-builder --force-clean --repo="$REPO_DIR" "$BUILD_DIR" "$MANIFEST"
flatpak build-bundle "$REPO_DIR" "$BUNDLE_PATH" com.bulkheados.CodexForLinux

cat <<EOF
Local Flatpak bundle created:
  $BUNDLE_PATH

Install locally:
  flatpak install --user "$BUNDLE_PATH"

KDE Discover can manage the installed app after it is installed through Flatpak.

Warning:
  This local Flatpak grants home-directory access so Codex can open your chosen
  project paths. Keep the bundle private unless you have redistribution rights.
EOF
