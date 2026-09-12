#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────────────────
# update_build_tracker.sh — regenerate the Component Registry section of
# /mnt/Lucy/I30LTZ_RECOVERY_BUILD_TRACKER.md with live build data.
#
# Run after every build or sync. Does not require root.
# ─────────────────────────────────────────────────────────────────────────────

LUCY="/mnt/Lucy"
TRACKER="$LUCY/I30LTZ_RECOVERY_BUILD_TRACKER.md"
TS=$(date '+%Y-%m-%d %H:%M')

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Updating I30LTZ Recovery build tracker..."

# ── Helper: get file info or placeholder ─────────────────────────────────
sha16() {
    local f="$1"
    if [ -f "$f" ]; then
        sha256sum "$f" | cut -c1-16
    else
        echo "—"
    fi
}
sz() {
    local f="$1"
    if [ -f "$f" ]; then
        du -sh "$f" 2>/dev/null | awk '{print $1}'
    else
        echo "—"
    fi
}
mtime() {
    local f="$1"
    if [ -f "$f" ]; then
        stat -c '%Y' "$f" | xargs -I{} date -d @{} '+%Y-%m-%d %H:%M'
    else
        echo "—"
    fi
}

# ── Gather versions ───────────────────────────────────────────────────────
SWARM_VER=$(cat "$LUCY/VERSION" 2>/dev/null || echo "—")

I30LTZ_BIN="$LUCY/30-source/i30ltz-recovery/target/release/i30ltz-recovery"
I30LTZ_VER=$(grep '^version' "$LUCY/30-source/i30ltz-recovery/Cargo.toml" 2>/dev/null | head -1 | grep -oP '["\d][^"]+' | tr -d '"' || echo "—")

SLINT_BIN="$LUCY/30-source/swarm-slint/target/release/swarm-slint"
SLINT_VER=$(grep '^version' "$LUCY/30-source/swarm-slint/Cargo.toml" 2>/dev/null | head -1 | grep -oP '["\d][^"]+' | tr -d '"' || echo "—")

FLUTTER_VER=$(grep '^version:' "$LUCY/30-source/frontend/pubspec.yaml" 2>/dev/null | awk '{print $2}' || echo "—")

LUCYSERVER_BIN="$LUCY/30-source/LucyServer-go/lucy-server"
GAMING_BIN="$LUCY/30-source/GamingAgent-go/gaming-agent"
LUCILLE_CORE_BIN="$LUCY/30-source/lucille-core/build/lucille-core"

# ── Generate new Component Registry section ───────────────────────────────
NEW_REGISTRY=$(cat <<REGISTRY
## Component Registry

_Last updated: ${TS}_

### UI Layer

| Component | Language | Version | Built | Size | SHA256 (first 16) |
|---|---|---|---|---|---|
| DR. I30LTZ Recovery | Rust + Raylib | ${I30LTZ_VER} | $(mtime "$I30LTZ_BIN") | $(sz "$I30LTZ_BIN") | \`$(sha16 "$I30LTZ_BIN")\` |
| Lucille Panel (swarm-slint) | Rust + Slint | ${SLINT_VER} | $(mtime "$SLINT_BIN") | $(sz "$SLINT_BIN") | \`$(sha16 "$SLINT_BIN")\` |
| Flutter Shell (frontend) | Dart / Flutter | ${FLUTTER_VER} | — | — | staged in ISO |

### Backend Services

| Component | Language | Version | Built | Size | SHA256 (first 16) | Port |
|---|---|---|---|---|---|---|
| LucyServer-go | Go 1.26 | ${SWARM_VER} | $(mtime "$LUCYSERVER_BIN") | $(sz "$LUCYSERVER_BIN") | \`$(sha16 "$LUCYSERVER_BIN")\` | 5000 |
| GamingAgent-go | Go 1.23 | ${SWARM_VER} | $(mtime "$GAMING_BIN") | $(sz "$GAMING_BIN") | \`$(sha16 "$GAMING_BIN")\` | 8401 |
| GoogleWorkspaceService | .NET 10 / C# | ${SWARM_VER} | ISO build | — | staged in ISO | 5002 |
| lucille-core | C++20 | — | $(mtime "$LUCILLE_CORE_BIN") | $(sz "$LUCILLE_CORE_BIN") | \`$(sha16 "$LUCILLE_CORE_BIN")\` | native lib |

### ISO / OS

| Component | Version | Date | Notes |
|---|---|---|---|
| SWARM OS ISO | ${SWARM_VER} | ${TS} | \`10-releases/\` — auto-bumped on build |
| Arch packages.x86_64 | — | 2026-09-12 | aspnet-runtime-10.0 added |

### Scripts

| Script | Last Updated | Notes |
|---|---|---|
| \`build_swarm_iso_6.2.19_2026-09-08.sh\` | $(stat -c '%y' "$LUCY/70-scripts/build_swarm_iso_6.2.19_2026-09-08.sh" 2>/dev/null | cut -d' ' -f1 || echo "—") | Builds all components + ISO |
| \`sync_lucille_ai.sh\` | $(stat -c '%y' "$LUCY/70-scripts/sync_lucille_ai.sh" 2>/dev/null | cut -d' ' -f1 || echo "—") | rsync --checksum, Lucille-AI + I30LTZ-Recovery |
| \`update_build_tracker.sh\` | $(stat -c '%y' "$LUCY/70-scripts/update_build_tracker.sh" 2>/dev/null | cut -d' ' -f1 || echo "—") | Regenerates this file |
| \`unlock_slick.sh\` | $(stat -c '%y' "$LUCY/70-scripts/unlock_slick.sh" 2>/dev/null | cut -d' ' -f1 || echo "—") | Opens LUKS slick partition |
| \`install_swarm_os.sh\` | $(stat -c '%y' "$LUCY/30-source/install_swarm_os.sh" 2>/dev/null | cut -d' ' -f1 || echo "—") | Live USB → NVMe installer |
REGISTRY
)

# ── Replace the Component Registry section in the tracker ─────────────────
# Strategy: keep everything before "## Component Registry" and after the
# next "---" separator that follows it, then insert new content in between.

BEFORE=$(awk '/^## Component Registry/{exit} {print}' "$TRACKER")
AFTER=$(awk '/^## Binary Locations by OS/{found=1} found{print}' "$TRACKER")

{
    echo "$BEFORE"
    echo ""
    echo "$NEW_REGISTRY"
    echo ""
    echo "---"
    echo ""
    echo "$AFTER"
} > "${TRACKER}.tmp"

mv "${TRACKER}.tmp" "$TRACKER"

echo "Done — build tracker updated: $TRACKER"
