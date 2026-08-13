#!/usr/bin/env bash

set -e

VERSION="1.1.0"
RELEASE_DIR="fedora-wifi-hotspot-$VERSION"
TARBALL="$RELEASE_DIR.tar.gz"

echo "[*] Creating release package for v$VERSION..."

# Clean up previous builds
rm -rf "$RELEASE_DIR" "$TARBALL"

# Create release directory
mkdir "$RELEASE_DIR"

# Copy necessary files
cp -r lib "$RELEASE_DIR/"
cp install.sh uninstall.sh wifi-hotspot wifi-hotspot-gui README.md LICENSE "$RELEASE_DIR/"

# Create the tarball
tar -czf "$TARBALL" "$RELEASE_DIR"

# Clean up temporary directory
rm -rf "$RELEASE_DIR"

echo "[✓] Successfully created release tarball: $TARBALL"
echo "You can now upload $TARBALL to your GitHub Releases page!"
