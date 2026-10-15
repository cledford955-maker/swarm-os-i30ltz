#!/usr/bin/env bash
# deploy_to_installed.sh — put a freshly built Flutter shell and Go services into
# the INSTALLED SWARM OS root (nvme0n1p2, label swarm-root) from another OS,
# without rebooting or reformatting anything.
#
#   deploy_to_installed.sh [--dry-run] [--no-snapshot-check] [--flutter-only]
#
#   --flutter-only   update just the Flutter shell bundle; leave gaming-agent, lucy-server and
#                    swarm-memory exactly as they are (and do not require them to be built)
#
# What it updates (built on /mnt/swarmbuild, per CLAUDE.md):
#   opt/swarm_os/swarm_flutter/   Flutter shell bundle
#   opt/swarm_os/GamingAgent/     gaming-agent
#   opt/swarm_os/LucyServer/      lucy-server
#   usr/local/bin/swarm-memory
# It does NOT touch Arch packages, fstab, users or home dirs. After verifying
# the payloads it updates /etc/swarm-release so the installed version is honest.
#
# Safety, in this order — nothing is written until every check has passed:
#   * the target must be the swarm-root partition, mounted, not the running root;
#   * a btrfs snapshot of @ no older than 60 min must exist
#     (sudo 70-scripts/snapshot_before_update.sh <label>), unless
#     --no-snapshot-check;
#   * every library the new shell needs must exist in the target root or the
#     bundle, and its glibc requirement must not exceed the target's. A stale
#     plugin .so needing a library the target lacks once blanked the screen on
#     boot (2026-09-13), so this is checked on the real files, not assumed;
#   * each old component is RENAMED to <name>.bak-<stamp>, never deleted, so a
#     bad copy cannot leave the system without a shell.
# Roll back one component: rm -rf <name>; mv <name>.bak-<stamp> <name>
# Roll back everything: boot the snapshot entry in GRUB, or swap @snapshots/<snap> in.
set -euo pipefail

DRY=0; SNAPCHECK=1; FLUTTER_ONLY=0
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --no-snapshot-check) SNAPCHECK=0 ;;
    --flutter-only) FLUTTER_ONLY=1 ;;
    *) echo "unknown option: $a" >&2; exit 2 ;;
  esac
done

ROOT_DEV=/dev/nvme0n1p2
SRC=${SWARM_BUILD_SRC:-/mnt/swarmbuild/30-source}
BUNDLE=$SRC/frontend/build/linux/x64/release/bundle
GAMING=$SRC/GamingAgent-go/gaming-agent
LUCY=$SRC/LucyServer-go/lucy-server
MEMORY=$SRC/LucyServer-go/swarm-memory
STAMP=$(date +%Y%m%d-%H%M%S)

die()  { echo "REFUSED: $*" >&2; exit 1; }
say()  { echo "  $*"; }
run()  { if [ "$DRY" = 1 ]; then echo "  [dry-run] $*"; else "$@"; fi; }

# ── target checks ────────────────────────────────────────────────────────────
[ -b "$ROOT_DEV" ] || die "$ROOT_DEV does not exist"
[ "$(lsblk -no LABEL "$ROOT_DEV" | head -n1)" = swarm-root ] || die "$ROOT_DEV is not labelled swarm-root"
[ "$(findmnt -no SOURCE / | sed 's/\[.*//')" != "$ROOT_DEV" ] || die "$ROOT_DEV is the running root; deploy from another OS"
TOP=$(findmnt -rn -S "$ROOT_DEV" -o TARGET | head -n1 || true)
[ -n "$TOP" ] || die "$ROOT_DEV is not mounted (mount its top level, e.g. /mnt/swarm)"
R=$TOP/@
[ -f "$R/etc/swarm-release" ] || die "$R does not look like a SWARM OS root (no etc/swarm-release)"
[ -d "$R/opt/swarm_os" ] || die "$R/opt/swarm_os missing"
DIRS="etc opt/swarm_os opt/swarm_os/GamingAgent opt/swarm_os/LucyServer usr/local/bin"
[ "$FLUTTER_ONLY" = 1 ] && DIRS="opt/swarm_os"
for d in $DIRS; do
  [ -d "$R/$d" ] || die "$R/$d missing"
  [ -w "$R/$d" ] || die "$R/$d is not writable as $(id -un) — re-run with sudo (nothing has been changed)"
done
say "target: $R  ($(grep -h SWARM_VERSION "$R/etc/swarm-release"))"

# ── source checks ────────────────────────────────────────────────────────────
GO_BINS=("$GAMING" "$LUCY" "$MEMORY")
[ "$FLUTTER_ONLY" = 1 ] && GO_BINS=()
for f in "$BUNDLE/swarm_flutter" "$BUNDLE/lib/libapp.so" "${GO_BINS[@]}"; do
  [ -f "$f" ] || die "missing build output: $f"
done
[ -d "$BUNDLE/data/flutter_assets" ] || die "bundle has no data/flutter_assets"
for f in "${GO_BINS[@]}" "$BUNDLE/swarm_flutter"; do
  [ "$(head -c4 "$f" | od -An -c | tr -d ' ')" = '177ELF' ] || die "$f is not an ELF binary"
done

# ── fresh snapshot? ──────────────────────────────────────────────────────────
if [ "$SNAPCHECK" = 1 ]; then
  newest=$(ls -1 "$TOP/@snapshots" 2>/dev/null | grep -E '^swarm-[0-9]{8}-[0-9]{6}' | sort | tail -n1 || true)
  [ -n "$newest" ] || die "no snapshot in $TOP/@snapshots — run: sudo 70-scripts/snapshot_before_update.sh pre-deploy"
  ts=$(echo "$newest" | sed -E 's/^swarm-([0-9]{8})-([0-9]{2})([0-9]{2})([0-9]{2}).*/\1 \2:\3:\4/')
  age=$(( $(date +%s) - $(date -d "$ts" +%s) ))
  [ "$age" -le 3600 ] || die "newest snapshot ($newest) is $((age/60)) min old; take a fresh one first"
  say "snapshot ok: $newest ($((age/60)) min old)"
fi

# ── library + glibc compatibility of the new shell, on the real files ───────
missing=0
for f in "$BUNDLE/swarm_flutter" "$BUNDLE"/lib/*.so; do
  for n in $(readelf -d "$f" 2>/dev/null | sed -n 's/.*NEEDED.*\[\(.*\)\]/\1/p'); do
    if [ -e "$BUNDLE/lib/$n" ] || [ -e "$R/usr/lib/$n" ] || [ -e "$R/usr/lib64/$n" ] || [ -e "$R/lib/$n" ]; then :; else
      echo "  MISSING in target: $n (needed by $(basename "$f"))" >&2; missing=1
    fi
  done
done
[ "$missing" = 0 ] || die "the new shell needs libraries the installed system does not have"
have_glibc=$(strings "$R/usr/lib/libc.so.6" | sed -n 's/.*GNU C Library.*version \([0-9.]*\).*/\1/p' | head -n1)
have_glibc=${have_glibc%.}
need_glibc=$( { for f in "$BUNDLE/swarm_flutter" "$BUNDLE"/lib/*.so "${GO_BINS[@]}"; do objdump -T "$f" 2>/dev/null | grep -o 'GLIBC_[0-9.]*'; done; } | sed 's/GLIBC_//' | sort -uV | tail -n1)
[ -n "$have_glibc" ] && [ -n "$need_glibc" ] || die "could not read glibc versions"
[ "$(printf '%s\n%s\n' "$need_glibc" "$have_glibc" | sort -V | tail -n1)" = "$have_glibc" ] || die "new binaries need glibc $need_glibc, target has $have_glibc"
say "libraries ok; glibc need $need_glibc <= target $have_glibc"

# ── swap one component in, keeping the old one ───────────────────────────────
swap_dir() {   # <source dir> <dest dir>
  local src=$1 dest=$2
  run rm -rf "$dest.new-$STAMP"
  run cp -a --no-preserve=ownership "$src" "$dest.new-$STAMP"   # never carry the builder's uid onto the installed root
  if [ -e "$dest" ]; then run mv "$dest" "$dest.bak-$STAMP"; fi
  run mv "$dest.new-$STAMP" "$dest"
  say "$(basename "$dest"): updated (old kept as $(basename "$dest").bak-$STAMP)"
}
swap_file() {  # <source file> <dest file>
  local src=$1 dest=$2
  run cp -f --preserve=mode,timestamps "$src" "$dest.new-$STAMP"
  run chmod +x "$dest.new-$STAMP"
  if [ -e "$dest" ]; then run mv "$dest" "$dest.bak-$STAMP"; fi
  run mv "$dest.new-$STAMP" "$dest"
  say "$(basename "$dest"): updated (old kept as $(basename "$dest").bak-$STAMP)"
}

echo "deploying ($([ "$DRY" = 1 ] && echo dry-run || echo real)) ..."
swap_dir  "$BUNDLE" "$R/opt/swarm_os/swarm_flutter"
run chmod +x "$R/opt/swarm_os/swarm_flutter/swarm_flutter"
if [ "$FLUTTER_ONLY" = 0 ]; then
  run mkdir -p "$R/opt/swarm_os/GamingAgent" "$R/opt/swarm_os/LucyServer"
  swap_file "$GAMING" "$R/opt/swarm_os/GamingAgent/gaming-agent"
  swap_file "$LUCY"   "$R/opt/swarm_os/LucyServer/lucy-server"
  swap_file "$MEMORY" "$R/usr/local/bin/swarm-memory"
else
  say "gaming-agent, lucy-server, swarm-memory: left as they are (--flutter-only)"
fi

# ── verify what landed ───────────────────────────────────────────────────────
if [ "$DRY" = 0 ]; then
  diff -rq "$BUNDLE" "$R/opt/swarm_os/swarm_flutter" >/dev/null || die "shell bundle on target differs from the build"
  if [ "$FLUTTER_ONLY" = 0 ]; then
    cmp -s "$GAMING" "$R/opt/swarm_os/GamingAgent/gaming-agent"    || die "gaming-agent differs from the build"
    cmp -s "$LUCY"   "$R/opt/swarm_os/LucyServer/lucy-server"      || die "lucy-server differs from the build"
    cmp -s "$MEMORY" "$R/usr/local/bin/swarm-memory"               || die "swarm-memory differs from the build"
  fi
  echo "verified: every file on the target matches the build."
  # History line only; the deploy is already verified. An earlier sudo deploy can leave this
  # file root-owned, which must not turn a good deploy into a failed run.
  { printf 'deployed %s from %s\n' "$STAMP" "$SRC" >> "$R/opt/swarm_os/.deploy-log"; } 2>/dev/null \
    || echo "  note: could not append to $R/opt/swarm_os/.deploy-log (owned by $(stat -c %U "$R/opt/swarm_os/.deploy-log" 2>/dev/null || echo '?'))"
fi

# Record the source version only after all deployed payloads match. Dirty source
# trees are labelled explicitly rather than pretending the binaries are a commit.
VERSION_FILE="${SWARM_BUILD_ROOT:-/mnt/swarmbuild}/VERSION"
[ -s "$VERSION_FILE" ] || die "missing source version file: $VERSION_FILE"
SWARM_VERSION=$(tr -d '[:space:]' < "$VERSION_FILE")
[[ "$SWARM_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "invalid source version: $SWARM_VERSION"
SWARM_COMMIT=$(git -C "${SWARM_BUILD_ROOT:-/mnt/swarmbuild}" rev-parse --short=8 HEAD 2>/dev/null || echo unknown)
if [ -n "$(git -C "${SWARM_BUILD_ROOT:-/mnt/swarmbuild}" status --porcelain 2>/dev/null)" ]; then
  SWARM_COMMIT+="-dirty"
fi
SWARM_DATE=$(date +%Y%m%d)
if [ "$FLUTTER_ONLY" = 1 ]; then
  say 'release marker left unchanged for --flutter-only deployment'
elif [ "$DRY" = 1 ]; then
  say "[dry-run] would set $R/etc/swarm-release to v$SWARM_VERSION ($SWARM_COMMIT, $SWARM_DATE)"
else
  RELEASE_TMP=$(mktemp "$R/etc/swarm-release.new.XXXXXX")
  printf 'SWARM_VERSION=%s\nSWARM_COMMIT=%s\nSWARM_DATE=%s\n' \
    "$SWARM_VERSION" "$SWARM_COMMIT" "$SWARM_DATE" > "$RELEASE_TMP"
  chmod --reference="$R/etc/swarm-release" "$RELEASE_TMP"
  mv -f "$RELEASE_TMP" "$R/etc/swarm-release"
  say "installed version marker updated to v$SWARM_VERSION ($SWARM_COMMIT)"
fi
echo "done. Old versions are the *.bak-$STAMP next to each component."
