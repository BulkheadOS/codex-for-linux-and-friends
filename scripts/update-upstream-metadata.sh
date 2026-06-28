#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT="${1:-$PROJECT_DIR/.upstream/codex-app.json}"

mkdir -p "$(dirname "$OUTPUT")"

node "$PROJECT_DIR/lib/upstream-metadata.mjs" --arch x64 --output "$OUTPUT" --write
node "$PROJECT_DIR/lib/upstream-metadata.mjs" --arch arm64 --output "$PROJECT_DIR/.upstream/codex-app-arm64.json" --write

if git -C "$PROJECT_DIR" diff --quiet -- .upstream; then
  echo "No upstream metadata changes detected."
else
  echo "Upstream metadata changed:"
  git -C "$PROJECT_DIR" diff -- .upstream
fi
