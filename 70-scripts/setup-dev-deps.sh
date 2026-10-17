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
    unzip \
    gitleaks

# ── Git pre-commit hook: secret scanner ─────────────────────────────────────
# Catches credentials before they reach the 10-minute auto-sync commits.
# Closes audit standing item av4.
HOOK="/mnt/Lucy/.git/hooks/pre-commit"
if [ ! -f "$HOOK" ]; then
    echo "Installing gitleaks pre-commit hook..."
    mkdir -p "$(dirname "$HOOK")"
    cat > "$HOOK" <<'HOOK_EOF'
#!/usr/bin/env bash
# SWARM OS — gitleaks pre-commit secret scanner.
# Installed by setup-dev-deps.sh. Blocks commits that contain secrets.
if ! command -v gitleaks &>/dev/null; then
    echo "[pre-commit] gitleaks not found — skipping secret scan"
    exit 0
fi
gitleaks protect --staged --no-banner || {
    echo ""
    echo "[pre-commit] gitleaks: secret detected — commit aborted."
    echo "If this is a false positive, commit with: git commit --no-verify"
    exit 1
}
HOOK_EOF
    chmod 755 "$HOOK"
    echo "✓ Pre-commit hook installed at $HOOK"
else
    echo "Pre-commit hook already exists at $HOOK — not overwritten."
fi

echo ""
echo "All done. Flutter SDK is at /mnt/Lucy/30-source/flutter-sdk/"
echo "Add to your shell profile:"
echo "  export PATH=\"/mnt/Lucy/30-source/flutter-sdk/bin:\$PATH\""
echo "  export FLUTTER_ROOT=\"/mnt/Lucy/30-source/flutter-sdk\""
echo ""
echo "Verify with: flutter doctor"
