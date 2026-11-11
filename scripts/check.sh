#!/bin/sh
# Runs luacheck (static analysis) and busted (tests) on the addon.
# The pre-push hook (.githooks/pre-push) runs this before a release tag is pushed.
#
# Setup (once):
#   brew install luarocks luajit
#   luarocks --lua-version=5.1 --local install busted
#   luarocks --lua-version=5.1 --local install luacheck
#   git config core.hooksPath .githooks
set -e
cd "$(dirname "$0")/.."
PATH="$HOME/.luarocks/bin:$PATH"

for tool in luacheck busted; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "check.sh: $tool is not installed – see the setup at the top of scripts/check.sh" >&2
        exit 1
    fi
done

echo "== luacheck"
luacheck . -q
echo "== busted"
busted
