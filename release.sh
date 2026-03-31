#!/usr/bin/env zsh
# Release a new version of nevo-git and update the Homebrew formula.
# Usage: ./release.sh ["commit message"]

set -e

FORMULA_REPO="$HOME/workspace/homebrew-nevo"
FORMULA_FILE="$FORMULA_REPO/Formula/nevo-git.rb"

MESSAGE="${1:-release}"

# Get current version from the latest tag and bump patch
LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "v0.0.0")
MAJOR=$(echo "$LATEST_TAG" | sed 's/v//' | cut -d. -f1)
MINOR=$(echo "$LATEST_TAG" | sed 's/v//' | cut -d. -f2)
PATCH=$(echo "$LATEST_TAG" | sed 's/v//' | cut -d. -f3)
NEW_TAG="v${MAJOR}.${MINOR}.$((PATCH + 1))"

echo "Current: $LATEST_TAG -> New: $NEW_TAG"
echo "Message: $MESSAGE"
echo ""

# 1. Commit if there are changes, then tag and push
if [[ -n "$(git status --porcelain)" ]]; then
    git add -A
    git commit -m "$MESSAGE"
fi
git tag "$NEW_TAG"
git push
git push origin "$NEW_TAG"
echo "Pushed $NEW_TAG to nevo-git"

# 2. Get the tarball SHA
REPO_URL=$(git remote get-url origin | sed 's|git@github.com:|https://github.com/|; s|\.git$||; s|https://[^@]*@github.com/|https://github.com/|')
TARBALL_URL="${REPO_URL}/archive/refs/tags/${NEW_TAG}.tar.gz"
SHA=$(curl -sL "$TARBALL_URL" | shasum -a 256 | cut -d' ' -f1)
echo "SHA256: $SHA"

# 3. Update the formula
OLD_URL=$(grep 'url "' "$FORMULA_FILE" | sed 's/.*url "//; s/"//')
OLD_SHA=$(grep 'sha256 "' "$FORMULA_FILE" | sed 's/.*sha256 "//; s/"//')

sed -i '' "s|$OLD_URL|$TARBALL_URL|" "$FORMULA_FILE"
sed -i '' "s|$OLD_SHA|$SHA|" "$FORMULA_FILE"

# 4. Commit and push formula
cd "$FORMULA_REPO"
git add -A
git commit -m "bump to $NEW_TAG ($MESSAGE)"
git push
echo ""
echo "Done! Released $NEW_TAG"
echo "Users can run: brew upgrade nevo-git"
