#!/bin/bash
# Tests the release tooling (cask rendering and the update script) without touching the network.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT=$(pwd)
fail() { echo "FAIL: $*" >&2; exit 1; }

A=$(printf 'a%.0s' {1..64}); B=$(printf 'b%.0s' {1..64})

# --- render-cask.sh ---
out=$(./Scripts/render-cask.sh 1.2.3 "$A")
grep -q 'version "1.2.3"' <<<"$out" || fail "version not rendered"
grep -q "sha256 \"$A\"" <<<"$out" || fail "sha not rendered"
! grep -q '__' <<<"$out" || fail "unreplaced placeholder left in cask"
if command -v ruby >/dev/null; then ruby -c <<<"$out" >/dev/null || fail "cask is not valid Ruby"; fi

./Scripts/render-cask.sh 1.2.3 nothex >/dev/null 2>&1 && fail "bad sha accepted"
./Scripts/render-cask.sh v1.2.3 "$A" >/dev/null 2>&1 && fail "v-prefixed version accepted"
./Scripts/render-cask.sh 1.2.3 >/dev/null 2>&1 && fail "missing sha accepted"

# --- update-cask.sh against a throwaway remote ---
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
git init -q --bare "$tmp/remote.git"
git clone -q "$tmp/remote.git" "$tmp/work" 2>/dev/null
cd "$tmp/work"
git config user.name test; git config user.email test@example.com
git checkout -q -b master
mkdir Scripts && cp "$ROOT"/Scripts/*.sh "$ROOT"/Scripts/cask.rb.tmpl Scripts/
git add -A && git commit -q -m init && git push -q origin master

./Scripts/update-cask.sh 1.2.0 "$A" >/dev/null
grep -q 'version "1.2.0"' Casks/dozer.rb || fail "cask not created"
git -C "$tmp/remote.git" show master:Casks/dozer.rb | grep -q 'version "1.2.0"' || fail "cask not pushed"

./Scripts/update-cask.sh 1.2.0 "$A" | grep -q "already at 1.2.0" || fail "idempotence"
./Scripts/update-cask.sh 1.1.0 "$B" | grep -q "newer than 1.1.0" || fail "cask moved backwards"
./Scripts/update-cask.sh 1.10.0 "$B" >/dev/null
git -C "$tmp/remote.git" show master:Casks/dozer.rb | grep -q 'version "1.10.0"' || fail "1.10.0 must sort after 1.2.0"

echo "release tooling OK"
