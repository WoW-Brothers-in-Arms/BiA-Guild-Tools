#!/usr/bin/env bash
# Uploads the release zip to CurseForge (https://support.curseforge.com/en/support/solutions/articles/9000197321).
# Game versions come from "## Interface:" in the TOC: 120105 -> "12.1.5", 16001 -> "1.60.1".
# Each one is looked up by name in CurseForge's version list; versions CurseForge doesn't know are
# skipped with a warning, and the upload fails if none is left.
# The file is listed on CurseForge under the bare version (e.g. "1.2.0").
# Usage: curseforge-upload.sh <tag> <zip filename> <changelog file>
# Needs CF_API_KEY and CF_PROJECT_ID in the environment. CF_API_BASE can point to a test server.
set -euo pipefail
tag="$1"
zip="$2"
changelog="$3"
api="${CF_API_BASE:-https://wow.curseforge.com/api}"
toc="$(dirname "$0")/../BiAGuildTools/BiAGuildTools.toc"

case "$tag" in
  *alpha*) release_type=alpha ;;
  *beta*) release_type=beta ;;
  *) release_type=release ;;
esac

wanted=$(sed -n 's/^## Interface: *//p' "$toc" | tr -d '\r' | tr ',' '\n' | tr -d ' ' | grep . |
  jq -R 'tonumber | "\(. / 10000 | floor).\(. % 10000 / 100 | floor).\(. % 100)"' | jq -s .)

versions=$(curl -fsS -H "X-Api-Token: $CF_API_KEY" "$api/game/versions")

ids=$(jq -n --argjson wanted "$wanted" --argjson versions "$versions" \
  '[$wanted[] as $w | $versions[] | select(.name == $w) | .id] | unique')
for name in $(jq -r '.[]' <<<"$wanted"); do
  if ! jq -e --arg n "$name" 'any(.[]; .name == $n)' <<<"$versions" >/dev/null; then
    echo "::warning::CurseForge does not know game version $name, skipping it"
  fi
done
if [ "$(jq length <<<"$ids")" -eq 0 ]; then
  echo "::error::None of the TOC game versions ($(jq -c . <<<"$wanted")) exist on CurseForge"
  exit 1
fi

metadata=$(jq -n --arg name "${tag#v}" --arg type "$release_type" \
  --rawfile changelog "$changelog" --argjson ids "$ids" \
  '{displayName: $name, releaseType: $type, changelog: $changelog, changelogType: "markdown", gameVersions: $ids}')
echo "Uploading $zip to CurseForge project $CF_PROJECT_ID: $(jq -c 'del(.changelog)' <<<"$metadata")"

# Read the metadata from a file: curl would misread ";" in an inline -F value (e.g. in the changelog).
metafile=$(mktemp)
trap 'rm -f "$metafile"' EXIT
printf '%s' "$metadata" >"$metafile"
curl -fsS -H "X-Api-Token: $CF_API_KEY" \
  -F "metadata=<$metafile;type=application/json" \
  -F "file=@$zip" \
  "$api/projects/$CF_PROJECT_ID/upload-file"
echo
