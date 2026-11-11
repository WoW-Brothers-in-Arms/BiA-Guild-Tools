#!/usr/bin/env bash
# Prints the CHANGELOG.md section for a version: the lines after "## <version>" (optionally followed
# by e.g. " (2026-11-12)") up to the next "## " heading, without leading/trailing blank lines.
# Fails if the section is missing or empty.
# Usage: changelog-section.sh <version>
set -euo pipefail
version="$1"
changelog="$(dirname "$0")/../CHANGELOG.md"

section=$(tr -d '\r' <"$changelog" | awk -v v="$version" '
  /^## / { if (found) exit; h = substr($0, 4); if (h == v || index(h, v " ") == 1) { found = 1; next } }
  found { print }
' | sed -e '/./,$!d' | sed -e ':a' -e '/^\n*$/{$d;N;ba' -e '}')

if [ -z "$section" ]; then
  echo "::error::CHANGELOG.md has no entries under '## $version'. Rename '## Unreleased' to '## $version (date)' before tagging." >&2
  exit 1
fi
printf '%s\n' "$section"
