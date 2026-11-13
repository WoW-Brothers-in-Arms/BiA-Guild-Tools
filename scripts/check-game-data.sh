#!/bin/sh
# Checks that the addon's recipe tables (BiAGuildTools/Modules/Professions/Categories.lua and Recipes.lua)
# were made from the client build installed here. A new Forever client build needs new tables:
#   python3 scripts/make-recipe-data.py <build>
# Runs from .githooks/pre-push before a release tag goes out. Without an installed client it only warns.
cd "$(dirname "$0")/.."
INFO="${WOW_BUILD_INFO:-/Applications/World of Warcraft/.build.info}"
DATA="BiAGuildTools/Modules/Professions/Categories.lua"

data=$(sed -n 's/^ns.ProfessionData.DATA_BUILD = "\(.*\)"$/\1/p' "$DATA")
recipes=$(sed -n 's/^ns.ProfessionData.DATA_BUILD = "\(.*\)"$/\1/p' "BiAGuildTools/Modules/Professions/Recipes.lua")
if [ -z "$data" ] || [ "$data" != "$recipes" ]; then
    echo "check-game-data: Categories.lua ($data) and Recipes.lua ($recipes) are not from the same build" >&2
    exit 1
fi
if [ ! -f "$INFO" ]; then
    echo "check-game-data: no client at $INFO – recipe tables of build $data not checked" >&2
    exit 0
fi
# .build.info: a header line naming the columns ("Version!STRING:0", "Product!STRING:0", ...), one line per product.
client=$(awk -F'|' '
    NR == 1 { for (i = 1; i <= NF; i++) { split($i, n, "!"); col[n[1]] = i }; next }
    $col["Product"] == "wowf" { print $col["Version"] }' "$INFO")
if [ -z "$client" ]; then
    echo "check-game-data: no Forever client (product wowf) in $INFO – recipe tables of build $data not checked" >&2
    exit 0
fi
if [ "$client" != "$data" ]; then
    echo "check-game-data: the recipe tables are from build $data, the installed client is $client." >&2
    echo "  Run: python3 scripts/make-recipe-data.py $client" >&2
    exit 1
fi
echo "check-game-data: recipe tables match client build $client"
