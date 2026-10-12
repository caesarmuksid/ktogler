#!/usr/bin/env bash
# Version bumping script for KWin Togler

set -e

VERSION_FILE="VERSION"
METADATA_FILE="metadata.json"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

if [ ! -f "$VERSION_FILE" ]; then
  echo -e "${RED}Error: VERSION file not found${NC}"
  exit 1
fi

CURRENT_VERSION=$(cat "$VERSION_FILE")

# Parse version (assuming semantic versioning: MAJOR.MINOR.PATCH)
IFS='.' read -r MAJOR MINOR PATCH <<<"$CURRENT_VERSION"

case "${1:-patch}" in
major)
  MAJOR=$((MAJOR + 1))
  MINOR=0
  PATCH=0
  ;;
minor)
  MINOR=$((MINOR + 1))
  PATCH=0
  ;;
patch)
  PATCH=$((PATCH + 1))
  ;;
*)
  echo -e "${RED}Unknown bump type: $1${NC}"
  echo "Usage: $0 [major|minor|patch]"
  exit 1
  ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"

echo -e "${YELLOW}Bumping version: ${CURRENT_VERSION} → ${NEW_VERSION}${NC}"

# Update VERSION file
echo "$NEW_VERSION" >"$VERSION_FILE"

# Update metadata.json
if [ -f "$METADATA_FILE" ]; then
  # Use sed to update version in metadata.json
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/\"Version\": \".*\"/\"Version\": \"$NEW_VERSION\"/" "$METADATA_FILE"
  else
    # Linux
    sed -i "s/\"Version\": \".*\"/\"Version\": \"$NEW_VERSION\"/" "$METADATA_FILE"
  fi
  echo -e "${GREEN}✓ Updated metadata.json${NC}"
fi

echo -e "${GREEN}✓ Version bumped to ${NEW_VERSION}${NC}"
echo ""
echo "Don't forget to:"
echo "  1. Review changes"
echo "  2. Commit: git commit -am 'Bump version to $NEW_VERSION'"
echo "  3. Tag: git tag v$NEW_VERSION"
echo "  4. Push: git push && git push --tags"
