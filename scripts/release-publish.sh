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

info "📦 Publishing release: ${GREEN}${TAG}${NC}"
echo

# Check if the draft release exists
if ! gh release view "${TAG}" &> /dev/null; then
    error "Release ${TAG} not found"
    info "Create a draft release first with: ./scripts/release-draft.sh"
    exit 1
fi

# Check if the release is a draft
RELEASE_INFO=$(gh release view "${TAG}" --json isDraft --jq .isDraft)
if [ "$RELEASE_INFO" != "true" ]; then
    error "Release ${TAG} is not a draft"
    info "This script only works with draft releases"
    exit 1
fi

info "🔍 Discovering bottle files..."

# Get all bottle assets from the release
BOTTLE_PATTERN="horse-${VERSION}.*.bottle.tar.gz"
BOTTLES=$(gh release view "${TAG}" --json assets --jq '.assets[].name' | grep ".bottle.tar.gz" || true)

if [ -z "$BOTTLES" ]; then
    error "No bottle files found in release ${TAG}"
    info ""
    info "Check the GitHub Actions workflow:"
    info "  https://github.com/notjosh/horse/actions/workflows/build-bottles.yml"
    info ""
    info "Once bottles are built, run this script again."
    exit 1
fi

# Validate and list bottles
BOTTLE_COUNT=0
while IFS= read -r bottle; do
    # Extract arch_os from filename: horse-VERSION.ARCH_OS.bottle.tar.gz
    if [[ "$bottle" =~ horse-${VERSION}\.([^.]+)\.bottle\.tar\.gz ]]; then
        ARCH_OS="${BASH_REMATCH[1]}"
        info "  Found: ${bottle} (${ARCH_OS})"
        BOTTLE_COUNT=$((BOTTLE_COUNT + 1))
    fi
done <<< "$BOTTLES"

if [ $BOTTLE_COUNT -eq 0 ]; then
    error "No valid bottle files found"
    exit 1
fi

success "✓ Found ${BOTTLE_COUNT} bottle(s)"
echo

# Download bottles and calculate SHA256s
info "📥 Downloading bottles and calculating SHA256s..."
TEMP_DIR=$(mktemp -d)
cd "${TEMP_DIR}"

# Download all bottles and store info in temporary file
BOTTLE_DATA_FILE="${TEMP_DIR}/bottle_data.txt"
> "$BOTTLE_DATA_FILE"

while IFS= read -r bottle; do
    if [[ "$bottle" =~ horse-${VERSION}\.([^.]+)\.bottle\.tar\.gz ]]; then
        ARCH_OS="${BASH_REMATCH[1]}"
        info "  Downloading ${bottle}..."
        gh release download "${TAG}" --pattern "${bottle}" --repo notjosh/horse
        
        SHA256=$(shasum -a 256 "${bottle}" | cut -d' ' -f1)
        info "    SHA256: ${SHA256}"
        
        # Store: arch_os|sha256
        echo "${ARCH_OS}|${SHA256}" >> "$BOTTLE_DATA_FILE"
    fi
done <<< "$BOTTLES"

cd - > /dev/null

success "✓ Bottles downloaded and verified"
echo

# Update the formula in homebrew-tap
info "📝 Updating Homebrew formula..."
ORIGINAL_DIR=$(pwd)
TAP_DIR=$(mktemp -d)
cd "${TAP_DIR}"

# Clone the tap repo
git clone git@github.com:notjosh/homebrew-tap.git
cd homebrew-tap

# Get source tarball SHA256
SOURCE_SHA256=$(curl -sL "https://github.com/notjosh/horse/archive/refs/tags/${TAG}.tar.gz" | shasum -a 256 | cut -d' ' -f1)

# Generate bottle block lines from stored data
# First pass: find the maximum arch_os length for alignment
MAX_ARCH_OS_LENGTH=0
while IFS='|' read -r arch_os sha256; do
    if [ ${#arch_os} -gt $MAX_ARCH_OS_LENGTH ]; then
        MAX_ARCH_OS_LENGTH=${#arch_os}
    fi
done < "${TEMP_DIR}/bottle_data.txt"

# Second pass: generate aligned bottle lines
BOTTLE_LINES=""
while IFS='|' read -r arch_os sha256; do
    # Calculate padding needed
    PADDING=$((MAX_ARCH_OS_LENGTH - ${#arch_os}))
    SPACES=$(printf '%*s' $PADDING '')
    
    # Format: sha256 cellar: :any_skip_relocation, arm64_sonoma: "sha256here"
    BOTTLE_LINES="${BOTTLE_LINES}    sha256 cellar: :any_skip_relocation, ${arch_os}:${SPACES} \"${sha256}\"\n"
done < "${TEMP_DIR}/bottle_data.txt"

# Create the formula with dynamically generated bottle blocks
cat > Formula/horse.rb << EOF
class Horse < Formula
  desc "Display an animated ASCII art carousel of horsesbr"
  homepage "https://github.com/notjosh/horse"
  url "https://github.com/notjosh/horse/archive/refs/tags/${TAG}.tar.gz"
  sha256 "${SOURCE_SHA256}"

  bottle do
    root_url "https://github.com/notjosh/horse/releases/download/${TAG}"
$(echo -e "${BOTTLE_LINES}")
  end

  depends_on "rust" => :build

  def install
    system "cargo", "install", *std_cargo_args
    man1.install "man/horse.1"
  end

  test do
    assert_path_exists bin/"horse"
  end
end
EOF

# Commit and push
git add Formula/horse.rb
git commit -m "horse ${VERSION}"
git push origin main

# Return to original directory before cleanup
cd "${ORIGINAL_DIR}"
rm -rf "${TAP_DIR}"
rm -rf "${TEMP_DIR}"

success "✓ Formula updated in homebrew-tap"
echo

# Publish the release
info "🚀 Publishing release..."
gh release edit "${TAG}" --draft=false

success "✓ Release published"
echo

success "🎉 Release ${TAG} completed successfully!"
info ""
info "View the release at: ${GREEN}https://github.com/notjosh/horse/releases/tag/${TAG}${NC}"
info ""
info "Users can now install or upgrade with:"
info "  ${GREEN}brew upgrade horse${NC}"
