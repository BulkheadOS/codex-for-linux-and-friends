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

for pattern in '*.dmg' '*.asar' '*.node' '*.so' '*.dylib' '*.zip' '*.app' '*.app/*' '*.app/**' '*.framework' '*.framework/*' '*.framework/**' 'Contents/Resources/*' 'runtime/*' 'dist/flatpak/runtime/*' 'node_modules/*' '.env' '.env.*'; do
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
  'g[h]o_[A-Za-z0-9_]+'
  'github[_]pat_[A-Za-z0-9_]+'
  's[k]-[A-Za-z0-9]{20,}'
  'OPENAI[_]API[_]KEY='
  '/home/[A-Za-z0-9._-]+'
  'BEGIN[ ]OPENSSH[ ]PRIVATE[ ]KEY'
  'BEGIN[ ]RSA[ ]PRIVATE[ ]KEY'
)

if [ -n "${HOME:-}" ] && [ "$HOME" != "/" ]; then
  escaped_home="$(printf '%s' "$HOME" | sed -E 's/[][(){}.^$*+?|\\/]/\\&/g')"
  secret_patterns+=("$escaped_home")
fi

for pattern in "${secret_patterns[@]}"; do
  scan_output=""
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    [ -f "$file" ] || continue
    matches="$(grep -InE "$pattern" "$file" 2>/dev/null || true)"
    if [ "$pattern" = '/home/[A-Za-z0-9._-]+' ]; then
      matches="$(printf '%s' "$matches" | grep -v '/home/linuxbrew' || true)"
    fi
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

if [ -d ".github/workflows" ]; then
  while IFS= read -r match; do
    workflow_file="${match%%:*}"
    rest="${match#*:}"
    line_number="${rest%%:*}"
    uses_value="$(printf '%s' "${match#*uses:}" | sed -E 's/#.*$//; s/^[[:space:]]+//; s/[[:space:]]+$//' | tr -d "\"'")"
    [ -n "$uses_value" ] || continue
    case "$uses_value" in
      ./*|../*|docker://*)
        continue
        ;;
    esac
    if ! printf '%s' "$uses_value" | grep -Eq '@[a-f0-9]{40}$'; then
      echo "GitHub Action is not pinned to a commit SHA: $workflow_file:$line_number $uses_value" >&2
      status=1
    fi
  done < <(grep -RInE '^[[:space:]]+-?[[:space:]]*uses:' .github/workflows 2>/dev/null || true)
fi

if [ "$status" -eq 0 ]; then
  echo "Public safety check passed."
fi

exit "$status"
