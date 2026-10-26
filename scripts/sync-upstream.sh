#!/usr/bin/env bash
# Backport of the upstream integration branch into this mirror (ADR 0010 §4).
# Fast-forward only: the mirror's master must stay identical to ezzz/HFRnow:swift (same SHAs).
# Run by the mirror's admin from a clean clone of francoisgn/ios-app_SwiftHFR:
#   ./scripts/sync-upstream.sh            # dry run: shows what would be pushed
#   ./scripts/sync-upstream.sh --push     # pushes the fast-forward to origin/master
# Stops without changing anything if the mirror has diverged.
set -euo pipefail

UPSTREAM_URL="${UPSTREAM_URL:-https://github.com/ezzz/HFRnow.git}"
UPSTREAM_BRANCH="${UPSTREAM_BRANCH:-swift}"
MIRROR_BRANCH="${MIRROR_BRANCH:-master}"
PUSH=false
[[ "${1:-}" == "--push" ]] && PUSH=true

git fetch --quiet origin "$MIRROR_BRANCH"
git fetch --quiet "$UPSTREAM_URL" "$UPSTREAM_BRANCH"
upstream="$(git rev-parse FETCH_HEAD)"
mirror="$(git rev-parse "origin/$MIRROR_BRANCH")"

if [[ "$upstream" == "$mirror" ]]; then
  echo "✓ Mirror already at upstream ${upstream:0:12}"
  exit 0
fi

if ! git merge-base --is-ancestor "$mirror" "$upstream"; then
  echo "✗ Diverged: origin/$MIRROR_BRANCH has commits that are not on $UPSTREAM_BRANCH." >&2
  echo "  Mirror-only commits (open them as PRs on $UPSTREAM_BRANCH, see ADR 0010 §4):" >&2
  git log --oneline "$upstream..$mirror" >&2
  exit 1
fi

echo "› Commits to bring into $MIRROR_BRANCH (${mirror:0:12} → ${upstream:0:12}):"
git log --oneline "$mirror..$upstream"

if $PUSH; then
  git push origin "$upstream:refs/heads/$MIRROR_BRANCH"
  echo "✓ Mirror fast-forwarded. Check CI on $MIRROR_BRANCH."
else
  echo "(dry run — re-run with --push to fast-forward origin/$MIRROR_BRANCH)"
fi
