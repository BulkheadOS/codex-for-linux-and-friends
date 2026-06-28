#!/usr/bin/env bash
set -Eeuo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Run this check inside a git repository." >&2
  exit 1
fi

status=0
candidate_files="$(git ls-files --cached --others --exclude-standard)"

for pattern in '*.dmg' '*.asar' '*.node' '*.so' '*.dylib' '*.zip' 'runtime/*' 'dist/flatpak/runtime/*' 'node_modules/*' '.env' '.env.*'; do
  if git ls-files --cached --others --exclude-standard -- "$pattern" | grep -q .; then
    echo "Forbidden tracked artifact pattern: $pattern" >&2
    git ls-files --cached --others --exclude-standard -- "$pattern" >&2
    status=1
  fi
done

while IFS= read -r file; do
  [ -n "$file" ] || continue
  size="$(wc -c <"$file")"
  if [ "$size" -gt 5242880 ]; then
    echo "Tracked file is larger than 5 MiB: $file ($size bytes)" >&2
    status=1
  fi
done <<EOF
$candidate_files
EOF

secret_patterns=(
  'gho_[A-Za-z0-9_]+'
  'github_pat_[A-Za-z0-9_]+'
  'sk-[A-Za-z0-9]{20,}'
  'OPENAI_API_KEY='
  '/home/ryan'
  'BEGIN OPENSSH PRIVATE KEY'
  'BEGIN RSA PRIVATE KEY'
)

for pattern in "${secret_patterns[@]}"; do
  scan_output=""
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    [ "$file" = "scripts/qa-public-safety.sh" ] && continue
    [ -f "$file" ] || continue
    matches="$(grep -InE "$pattern" "$file" 2>/dev/null || true)"
    if [ -n "$matches" ]; then
      scan_output="${scan_output}${matches}"$'\n'
    fi
  done <<EOF
$candidate_files
EOF
  if [ -n "$scan_output" ]; then
    echo "Potential secret or personal path matched pattern: $pattern" >&2
    printf '%s' "$scan_output" >&2
    status=1
  fi
done

if [ "$status" -eq 0 ]; then
  echo "Public safety check passed."
fi

exit "$status"
