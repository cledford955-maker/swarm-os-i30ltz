#!/usr/bin/env bash
# =============================================================================
# check_snapshot.sh — SWARM OS Arch snapshot preflight  (au1)
# v1.0.0 · 2026-09-12
#
# Proves, BEFORE mkarchiso spends 20 minutes, that:
#   1. the pinned archive.archlinux.org snapshot exists and is reachable,
#   2. every package named in packages.x86_64 actually resolves inside it,
#      by real name or by provides,
#   3. packages.x86_64 has no trailing inline comments (the 2026-09-11 bug:
#      mkarchiso only strips lines that START with '#', so "labwc  # note"
#      is fed to pacman as one bogus target).
#
# Exit 0 = snapshot is good to build against. Non-zero = do not build.
#
# Usage:  ./check_snapshot.sh [PROFILE_DIR]
# =============================================================================
set -euo pipefail

PROFILE_DIR="${1:-/mnt/Lucy/40-iso-profile/swarm_os_iso_profile}"
SNAPSHOT_FILE="$PROFILE_DIR/ARCH_SNAPSHOT"
PKG_FILE="$PROFILE_DIR/packages.x86_64"
BOOTSTRAP_FILE="$PROFILE_DIR/bootstrap_packages"
ARCHIVE_BASE="https://archive.archlinux.org/repos"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
fail() { echo -e "${RED}✗ $*${NC}" >&2; exit 1; }
ok()   { echo -e "${GREEN}✓ $*${NC}"; }
warn() { echo -e "${YELLOW}⚠ $*${NC}"; }

[ -f "$SNAPSHOT_FILE" ] || fail "No ARCH_SNAPSHOT at $SNAPSHOT_FILE — nothing is pinned."
[ -f "$PKG_FILE" ]      || fail "No packages.x86_64 at $PKG_FILE"

SNAPSHOT="$(grep -v '^[[:space:]]*#' "$SNAPSHOT_FILE" | grep -v '^[[:space:]]*$' | head -n1 | tr -d '[:space:]')"
[[ "$SNAPSHOT" =~ ^[0-9]{4}/[0-9]{2}/[0-9]{2}$ ]] \
    || fail "ARCH_SNAPSHOT holds '$SNAPSHOT' — expected YYYY/MM/DD."

echo -e "${CYAN}[snapshot] pinned to $SNAPSHOT${NC}"

# --- 1. no trailing inline comments (regression guard) -----------------------
if grep -qn '^[A-Za-z0-9][^#]*#' "$PKG_FILE"; then
    echo -e "${RED}packages.x86_64 has trailing inline comments on these lines:${NC}" >&2
    grep -n '^[A-Za-z0-9][^#]*#' "$PKG_FILE" >&2
    fail "mkarchiso does not strip them. Move each comment to its own line above."
fi
ok "packages.x86_64 has no trailing inline comments"

# --- 2. snapshot reachable ---------------------------------------------------
TMP="$(mktemp -d -t swarm-snapshot-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

declare -A PROVIDED=()
for repo in core extra; do
    url="$ARCHIVE_BASE/$SNAPSHOT/$repo/os/x86_64/$repo.db"
    echo "  fetching $repo.db …"
    if ! curl -fsSL --retry 3 --retry-delay 2 --max-time 120 -o "$TMP/$repo.db" "$url"; then
        fail "Cannot fetch $url
       Either the snapshot date does not exist, or this host has no route to
       archive.archlinux.org. Pick a different date in ARCH_SNAPSHOT, or fix
       connectivity — do NOT fall back to a rolling mirror."
    fi
    mkdir -p "$TMP/$repo"
    tar -xzf "$TMP/$repo.db" -C "$TMP/$repo" 2>/dev/null || fail "$repo.db is not a valid package database"

    # Each entry is <dir>/desc with %NAME% and %PROVIDES% sections.
    while IFS= read -r name; do
        [ -n "$name" ] && PROVIDED["$name"]=1
    done < <(
        find "$TMP/$repo" -name desc -print0 |
        xargs -0 awk '
            /^%NAME%$/      { mode="name"; next }
            /^%PROVIDES%$/  { mode="prov"; next }
            /^%[A-Z]+%$/    { mode="";     next }
            /^$/            { mode="";     next }
            mode=="name"    { print }
            mode=="prov"    { sub(/[<>=].*$/, "", $0); print }
        '
    )
done
ok "snapshot $SNAPSHOT reachable — ${#PROVIDED[@]} names/provides indexed across core+extra"

# --- 3. every requested package resolves ------------------------------------
missing=()
count=0
while IFS= read -r pkg; do
    pkg="$(echo "$pkg" | tr -d '[:space:]')"
    [ -z "$pkg" ] && continue
    case "$pkg" in \#*) continue ;; esac
    count=$((count + 1))
    [ -n "${PROVIDED[$pkg]:-}" ] || missing+=("$pkg")
done < <(cat "$PKG_FILE" "${BOOTSTRAP_FILE:-/dev/null}" 2>/dev/null)

if [ ${#missing[@]} -gt 0 ]; then
    echo -e "${RED}${#missing[@]} of $count packages do not exist in snapshot $SNAPSHOT:${NC}" >&2
    printf '    %s\n' "${missing[@]}" >&2
    fail "Fix packages.x86_64, or move the snapshot forward to a date that has them."
fi
ok "all $count packages resolve in snapshot $SNAPSHOT"

echo -e "${GREEN}[snapshot] preflight passed — safe to build.${NC}"
