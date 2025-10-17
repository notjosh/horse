#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

error() {
    echo -e "${RED}Error: $1${NC}" >&2
}

success() {
    echo -e "${GREEN}$1${NC}"
}

warning() {
    echo -e "${YELLOW}Warning: $1${NC}"
}

info() {
    echo -e "$1"
}

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    error "gh CLI is not installed. Please install it first:"
    info "  https://cli.github.com/"
    info "  Or run: brew install gh"
    exit 1
fi

# Extract version from Cargo.toml
VERSION=$(grep '^version = ' Cargo.toml | head -n1 | sed 's/version = "\(.*\)"/\1/')

if [ -z "$VERSION" ]; then
    error "Could not extract version from Cargo.toml"
    exit 1
fi

TAG="v${VERSION}"

info "📦 Preparing to release version: ${GREEN}${TAG}${NC}"
echo

# Check if working directory is clean
if [ -n "$(git status --porcelain)" ]; then
    error "Working directory is not clean. Please commit or stash your changes first."
    git status --short
    exit 1
fi

# Check if we're on main branch
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "main" ]; then
    error "You must be on the 'main' branch to create a release"
    info "Current branch: ${CURRENT_BRANCH}"
    info "Switch to main with: git checkout main"
    exit 1
fi

# Fetch latest from remote to ensure we have up-to-date refs
info "🔄 Fetching latest from remote..."
git fetch origin main

# Check if local main is in sync with remote main
LOCAL=$(git rev-parse main)
REMOTE=$(git rev-parse origin/main)

if [ "$LOCAL" != "$REMOTE" ]; then
    error "Local 'main' branch is not in sync with 'origin/main'"
    
    # Check if we're behind
    if git merge-base --is-ancestor main origin/main; then
        info "Local branch is behind remote. Pull the latest changes with:"
        info "  git pull origin main"
    # Check if we're ahead
    elif git merge-base --is-ancestor origin/main main; then
        info "Local branch is ahead of remote. Push your changes first with:"
        info "  git push origin main"
    else
        info "Branches have diverged. You may need to:"
        info "  git pull --rebase origin main"
    fi
    exit 1
fi

success "✓ On 'main' branch and in sync with remote"

# Check if tag exists locally
if git tag -l | grep -q "^${TAG}$"; then
    error "Tag ${TAG} already exists locally"
    info "If you need to re-release, delete the tag first:"
    info "  git tag -d ${TAG}"
    exit 1
fi

# Check if tag exists remotely
info "🔍 Checking if tag exists remotely..."
if git ls-remote --tags origin | grep -q "refs/tags/${TAG}$"; then
    error "Tag ${TAG} already exists on remote"
    info "Someone else may have already created this release."
    info "Pull the latest tags with: git fetch --tags"
    exit 1
fi

success "✓ Tag ${TAG} does not exist locally or remotely"
echo

# Show what will be done
info "The following actions will be performed:"
info "  1. Create git tag: ${TAG}"
info "  2. Push tag to origin"
info "  3. Create GitHub release with auto-generated notes"
echo

# Ask for confirmation
read -p "Do you want to proceed? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    warning "Release cancelled"
    exit 0
fi

echo

# Create the tag
info "🏷️  Creating tag ${TAG}..."
git tag "${TAG}"
success "✓ Tag created locally"

# Push the tag
info "📤 Pushing tag to origin..."
git push origin "${TAG}"
success "✓ Tag pushed to origin"

# Create GitHub release
info "🚀 Creating GitHub release..."
gh release create "${TAG}" --generate-notes
success "✓ GitHub release created"

echo
success "🎉 Release ${TAG} completed successfully!"
info ""
info "View the release at: ${GREEN}https://github.com/notjosh/manhorse/releases/tag/${TAG}${NC}"
info ""
info "The GitHub Actions workflow will now:"
info "  • Update Formula/horse.rb"
info "  • Commit and push the formula"
info ""
info "Check the status at: https://github.com/notjosh/manhorse/actions"
