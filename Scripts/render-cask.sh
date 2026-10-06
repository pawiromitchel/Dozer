#!/bin/bash
# Prints the Homebrew cask for a release.
#   render-cask.sh <version> <sha256 of Dozer.zip>
# <version> has no leading "v".
set -euo pipefail
cd "$(dirname "$0")/.."
[ "$#" -eq 2 ] || { echo "usage: $0 <version> <sha256>" >&2; exit 1; }
VERSION="$1"
SHA="$2"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "not a version: $VERSION" >&2; exit 1; }
[[ "$SHA" =~ ^[0-9a-f]{64}$ ]] || { echo "not a sha256: $SHA" >&2; exit 1; }

sed -e "s/__VERSION__/$VERSION/" -e "s/__SHA__/$SHA/" Scripts/cask.rb.tmpl
