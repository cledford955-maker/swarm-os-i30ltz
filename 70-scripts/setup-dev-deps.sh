#!/usr/bin/env bash
# =============================================================================
# SWARM OS — Dev Dependency Setup
# Run this once on any machine after mounting the LUCILLE drive at /mnt/Lucy.
# Flutter SDK is already on LUCILLE (30-source/flutter-sdk/) — no install needed.
# This script installs the OS-level tools that must come from pacman.
# =============================================================================
set -euo pipefail

if [ "$EUID" -eq 0 ]; then
    echo "ERROR: Run as normal user, not root."
    exit 1
fi

echo "Installing SWARM OS build dependencies via pacman..."
sudo pacman -Sy --needed \
    go \
    rust \
    dotnet-sdk-10.0 \
    dotnet-runtime-10.0 \
    aspnet-runtime-10.0 \
    cmake \
    ninja \
    base-devel \
    git \
    clang \
    libgtk-3-0 \
    gtk3 \
    curl \
    unzip

echo ""
echo "All done. Flutter SDK is at /mnt/Lucy/30-source/flutter-sdk/"
echo "Add to your shell profile:"
echo "  export PATH=\"/mnt/Lucy/30-source/flutter-sdk/bin:\$PATH\""
echo "  export FLUTTER_ROOT=\"/mnt/Lucy/30-source/flutter-sdk\""
echo ""
echo "Verify with: flutter doctor"
