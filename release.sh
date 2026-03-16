#!/usr/bin/env bash
# release.sh — Cut a versioned release.
#
# Usage: ./release.sh <VERSION>
#
# Steps:
#   1. Validates VERSION looks like X.Y.Z
#   2. Checks [Unreleased] has content
#   3. Renames [Unreleased] → [VERSION] - YYYY-MM-DD in CHANGELOG.md
#   4. Re-inserts an empty [Unreleased] heading above it
#   5. Updates VALIDATE_VERSION in validate.sh
#   6. Commits the changes
#   7. Creates annotated tag vVERSION
#   8. Moves the v1 floating tag forward
#
# The script does NOT push. Review the commit and tag, then push manually:
#   git push origin main --tags

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Args ---
if [[ $# -ne 1 ]] || [[ "$1" =~ ^(-h|--help)$ ]]; then
    echo "Usage: release.sh <VERSION>  (e.g. 1.4.0)"
    exit 1
fi

VERSION="$1"

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "error: VERSION must be semver (X.Y.Z), got '$VERSION'" >&2
    exit 1
fi

TAG="v${VERSION}"
TODAY=$(date '+%Y-%m-%d')

# --- Preflight ---
if git tag -l "$TAG" | grep -qF "$TAG"; then
    echo "error: tag $TAG already exists" >&2
    exit 1
fi

# Check [Unreleased] has content (at least one line between it and the next ##)
unreleased_content=$(sed -n '/^## \[Unreleased\]/,/^## \[/{/^## \[/d;p;}' "$REPO_ROOT/CHANGELOG.md" \
    | grep -cE '\S' || true)
if [[ "$unreleased_content" -eq 0 ]]; then
    echo "error: [Unreleased] section in CHANGELOG.md is empty" >&2
    exit 1
fi

# --- CHANGELOG.md ---
# Replace the [Unreleased] line with [Unreleased] + blank + [VERSION]
sed -i '' "s/^## \[Unreleased\]$/## [Unreleased]\n\n## [${VERSION}] - ${TODAY}/" \
    "$REPO_ROOT/CHANGELOG.md"
echo "updated CHANGELOG.md: [Unreleased] → [${VERSION}] - ${TODAY}"

# --- validate.sh ---
sed -i '' "s/^VALIDATE_VERSION=\".*\"/VALIDATE_VERSION=\"${VERSION}\"/" \
    "$REPO_ROOT/validate.sh"
echo "updated validate.sh: VALIDATE_VERSION=\"${VERSION}\""

# --- Commit ---
git -C "$REPO_ROOT" add CHANGELOG.md validate.sh
git -C "$REPO_ROOT" commit -m "chore: release ${VERSION}"
echo "committed release ${VERSION}"

# --- Tag ---
MAJOR="${VERSION%%.*}"
FLOATING_TAG="v${MAJOR}"

git -C "$REPO_ROOT" tag -a "$TAG" -m "$TAG"
echo "created tag $TAG"

# Move floating tag (delete + recreate so it can be force-pushed)
git -C "$REPO_ROOT" tag -d "$FLOATING_TAG" 2>/dev/null || true
git -C "$REPO_ROOT" tag -a "$FLOATING_TAG" -m "${FLOATING_TAG} — latest ${MAJOR}.x release (currently ${VERSION})"
echo "moved $FLOATING_TAG → ${VERSION}"

echo ""
echo "Done. Review, then push:"
echo "  git push origin main $TAG"
echo "  git push origin $FLOATING_TAG --force"
