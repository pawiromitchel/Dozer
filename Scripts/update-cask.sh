#!/bin/bash
# Commits the Homebrew cask for a release to master.
#   update-cask.sh <version> <sha256> [remote] [branch]
#
# The cask is a generated file, so this always starts from the newest branch head instead of merging, and it
# never moves the cask backwards (releases finishing out of order). Retries if the push races.
set -euo pipefail
VERSION="${1:?version}"
SHA="${2:?sha256}"
REMOTE="${3:-origin}"
BRANCH="${4:-master}"

for attempt in 1 2 3 4 5; do
  git fetch -q "$REMOTE" "$BRANCH"
  git reset -q --hard "$REMOTE/$BRANCH"

  current=$(sed -n 's/^  version "\([0-9][0-9.]*\)"/\1/p' Casks/dozer.rb 2>/dev/null | head -n1 || true)
  if [ -n "$current" ] && [ "$current" != "$VERSION" ] \
     && [ "$(printf '%s\n%s\n' "$current" "$VERSION" | sort -V | tail -n1)" = "$current" ]; then
    echo "Cask is already at $current, newer than $VERSION; leaving it alone."
    exit 0
  fi

  mkdir -p Casks
  ./Scripts/render-cask.sh "$VERSION" "$SHA" > Casks/dozer.rb
  git add Casks/dozer.rb
  if git diff --cached --quiet; then echo "Cask is already at $VERSION."; exit 0; fi
  git commit -q -m "chore(brew): update cask to $VERSION"
  if git push -q "$REMOTE" "HEAD:$BRANCH"; then echo "Cask updated to $VERSION."; exit 0; fi
  echo "Push failed (attempt $attempt), retrying from the latest $BRANCH..." >&2
  sleep $((attempt * 2))
done
echo "Could not update the cask." >&2
exit 1
