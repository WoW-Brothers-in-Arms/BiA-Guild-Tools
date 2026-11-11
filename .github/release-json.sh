#!/usr/bin/env bash
# Prints the release.json that WowUp (and other managers following the BigWigs packager format)
# use to pick the zip for each game client. Interfaces come from "## Interface:" in the TOC:
# 16xxx = WoW: Forever ("forever"), everything else = Retail ("mainline").
# Usage: release-json.sh <version> <zip filename>
set -euo pipefail
version="$1"
zip="$2"
toc="$(dirname "$0")/../BiAGuildTools/BiAGuildTools.toc"

sed -n 's/^## Interface: *//p' "$toc" | tr -d '\r' | tr ',' '\n' | tr -d ' ' | grep . |
  jq -R 'tonumber | {flavor: (if . >= 16000 and . < 17000 then "forever" else "mainline" end), interface: .}' |
  jq -s --arg v "$version" --arg f "$zip" \
    '{releases: [{name: "BiAGuildTools", version: $v, filename: $f, nolib: false, metadata: .}]}'
