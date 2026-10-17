#!/usr/bin/env bash
# =============================================================================
# verify_bundle_deps.sh — SWARM OS native dependency gate  (b1)
# v1.0.0 · 2026-09-12
#
# The kiosk shell dying one second after "Started SWARM OS Kiosk UI" is what an
# unresolved shared library looks like from the outside: systemd reports the
# unit started, the dynamic loader fails, nothing is ever drawn. The build host
# never notices, because on the build host the library IS there.
#
# This gate reads every DT_NEEDED soname out of the staged binaries and proves
# each one is provided by a package in the PINNED Arch snapshot (au1), or ships
# inside the bundle itself, or is staged into airootfs. Anything left over fails
# the build here instead of on the user's screen.
#
# Usage:  ./verify_bundle_deps.sh [PROFILE_DIR]
# =============================================================================
set -euo pipefail

PROFILE_DIR="${1:-/mnt/Lucy/40-iso-profile/swarm_os_iso_profile}"
AIROOTFS="$PROFILE_DIR/airootfs"
SNAPSHOT_FILE="$PROFILE_DIR/ARCH_SNAPSHOT"
CACHE_DIR="${SWARM_DEP_CACHE:-/mnt/Lucy/swarm_os_build_work/.depcache}"
ARCHIVE_BASE="https://archive.archlinux.org/repos"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
fail() { echo -e "${RED}✗ $*${NC}" >&2; exit 1; }
ok()   { echo -e "${GREEN}✓ $*${NC}"; }

command -v readelf >/dev/null 2>&1 || fail "readelf not found (pacman -S binutils)"

SNAPSHOT="$(grep -v '^[[:space:]]*#' "$SNAPSHOT_FILE" | grep -v '^[[:space:]]*$' | head -n1 | tr -d '[:space:]')"
[[ "$SNAPSHOT" =~ ^[0-9]{4}/[0-9]{2}/[0-9]{2}$ ]] || fail "ARCH_SNAPSHOT is not YYYY/MM/DD"
echo -e "${CYAN}[deps] verifying against snapshot $SNAPSHOT${NC}"

# --- build the set of sonames the pinned snapshot ships ----------------------
mkdir -p "$CACHE_DIR"
SONAME_INDEX="$CACHE_DIR/sonames-${SNAPSHOT//\//-}.txt"

if [ ! -s "$SONAME_INDEX" ]; then
    echo "  building soname index for $SNAPSHOT (first run for this snapshot, this takes a minute)…"
    TMP="$(mktemp -d -t swarm-deps-XXXXXX)"
    trap 'rm -rf "$TMP"' EXIT
    for repo in core extra; do
        url="$ARCHIVE_BASE/$SNAPSHOT/$repo/os/x86_64/$repo.files"
        curl -fsSL --retry 3 --retry-delay 2 --max-time 600 -o "$TMP/$repo.files" "$url" \
            || fail "Cannot fetch $url — is the snapshot date valid and the network up?"
        mkdir -p "$TMP/$repo"
        tar -xzf "$TMP/$repo.files" -C "$TMP/$repo" 2>/dev/null \
            || fail "$repo.files is not a valid database"
        # Every regular library path in the package file lists -> its basename.
        find "$TMP/$repo" -name files -print0 | xargs -0 cat |
            grep -oE '(usr/lib|usr/lib32|usr/bin)/[^[:space:]]*\.so[.0-9]*$' |
            sed 's|.*/||'
    done | sort -u > "$SONAME_INDEX"
    rm -rf "$TMP"; trap - EXIT
fi
[ -s "$SONAME_INDEX" ] || fail "soname index came out empty — refusing to pass a check that proves nothing"
ok "snapshot provides $(wc -l < "$SONAME_INDEX") distinct sonames"

# --- collect what the staged binaries actually need ---------------------------
declare -a TARGETS=()
while IFS= read -r f; do TARGETS+=("$f"); done < <(
    find "$AIROOTFS/opt/swarm_os" "$AIROOTFS/usr/bin/lucille-core" \
         -type f \( -name '*.so' -o -perm -u+x \) 2>/dev/null | sort
)
[ ${#TARGETS[@]} -gt 0 ] || fail "Nothing staged under $AIROOTFS/opt/swarm_os — run the build's staging step first"

# Sonames that ship inside the staged tree itself are self-satisfied.
LOCAL_SONAMES="$(printf '%s\n' "${TARGETS[@]}" | sed 's|.*/||' | sort -u)"

declare -A UNRESOLVED=()
checked=0
for bin in "${TARGETS[@]}"; do
    file "$bin" 2>/dev/null | grep -q ELF || continue
    checked=$((checked + 1))
    while IFS= read -r soname; do
        [ -z "$soname" ] && continue
        # linux-vdso / the loader itself are kernel-provided
        case "$soname" in linux-vdso.so.1|ld-linux-x86-64.so.2) continue ;; esac
        grep -qxF "$soname" "$SONAME_INDEX" && continue
        grep -qxF "$soname" <<< "$LOCAL_SONAMES" && continue
        find "$AIROOTFS" -name "$soname" -print -quit 2>/dev/null | grep -q . && continue
        UNRESOLVED["$soname"]="${UNRESOLVED[$soname]:-}${UNRESOLVED[$soname]:+, }$(basename "$bin")"
    done < <(readelf -d "$bin" 2>/dev/null | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p')
done

if [ ${#UNRESOLVED[@]} -gt 0 ]; then
    echo -e "${RED}${#UNRESOLVED[@]} shared libraries are needed but nothing in the ISO provides them:${NC}" >&2
    for soname in "${!UNRESOLVED[@]}"; do
        printf '    %-32s needed by: %s\n' "$soname" "${UNRESOLVED[$soname]}" >&2
    done
    cat >&2 <<'HINT'

  This is exactly the failure mode where the unit "starts" and then dies with
  nothing on screen. Fix one of:
    - add the providing package to packages.x86_64, or
    - remove the stale plugin library from the Flutter bundle
      (rm -rf 30-source/frontend/build/linux && rebuild — an incremental
       Flutter build keeps .so files for plugins that are no longer in
       pubspec.yaml, and they drag their own dependencies with them), or
    - stage the library into airootfs deliberately.
HINT
    exit 1
fi

ok "$checked staged ELF binaries — every DT_NEEDED soname resolves in snapshot $SNAPSHOT"
echo -e "${GREEN}[deps] dependency gate passed.${NC}"
