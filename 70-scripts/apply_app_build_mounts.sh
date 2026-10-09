#!/usr/bin/env bash
# Mount the three partitions added 2026-10-09 at their canonical points (policy: CLAUDE.md "App build partitions").
#
#   sudo 70-scripts/apply_app_build_mounts.sh                  fix /etc/fstab + mount (never formats)
#   sudo 70-scripts/apply_app_build_mounts.sh --reformat-boltz also turn D (NTFS) into ext4 first - see below
#   70-scripts/apply_app_build_mounts.sh --dry-run [...]       show the plan, change nothing (no sudo needed)
#   options: --yes  skip the typed confirmation of the reformat
#
#   /mnt/lucillebuild  C. Lucille build    Lucille Assistant build     PARTUUID d3bc74a6-...   ext4
#   /mnt/boltzbuild    D. BOLTZ Recovery   i30ltz Recovery app build   PARTUUID 52545158-...   NTFS -> ext4 (UUID e195839a-...)
#   /mnt/recoveryos    Recovery OS         Recovery OS root/home       PARTUUID 993d0098-...   btrfs (Samsung T7)
#
# Partitions are located by PARTUUID, which survives a reformat; each fstab row is built from the filesystem
# actually found (UUID + type), so the script is safe to re-run before and after the reformat.
# Only fstab lines for these mountpoints (and the old typo'd /mnt/llucillebuild) are replaced; /etc/fstab is backed up.
#
# --reformat-boltz (user decision 2026-10-09: "reformat the ntfs, it was a mistake"):
#   mkfs.ext4 on D only if ALL of these hold: PARTUUID matches, it sits on the Micron CT2000X9 drive, size is 150-180 GB,
#   it is currently NTFS, and it is EMPTY. It is formatted with the fixed UUID below so docs can already name it.
#   Nothing else is ever formatted.
set -euo pipefail
export PATH=/usr/sbin:/sbin:$PATH

DRY=0; REFORMAT=0; YES=0
for a in "$@"; do
  case $a in
    --dry-run) DRY=1 ;; --reformat-boltz) REFORMAT=1 ;; --yes) YES=1 ;;
    -h|--help) sed -n '2,24p' "$0"; exit 0 ;;
    *) echo "unknown option: $a (see --help)" >&2; exit 2 ;;
  esac
done
[[ $DRY -eq 0 && $EUID -ne 0 ]] && { echo "needs sudo:  sudo $0 $*" >&2; exit 1; }
OWNER_UID=${SUDO_UID:-$(id -u)}; OWNER_GID=${SUDO_GID:-$(id -g)}
HEADER="# ==== App build partitions (user decision 2026-10-09) - see /mnt/Lucy/CLAUDE.md ===="
BOLTZ_PARTUUID=52545158-4886-4f7e-8fed-7556cebaaefd
BOLTZ_LABEL="D. BOLTZ Recovery"
BOLTZ_EXT4_UUID=e195839a-f617-4abd-9bf3-b64a679b7474

# mountpoint|PARTUUID   (NOTE: do not name any variable LINES/COLUMNS/SECONDS/RANDOM/UID - bash owns those)
PARTS=(
  "/mnt/lucillebuild|d3bc74a6-018f-4529-96e2-7392bf698fd6"
  "/mnt/boltzbuild|$BOLTZ_PARTUUID"
  "/mnt/recoveryos|993d0098-1b2f-44a2-b51d-11c2bfeddc40"
)
DROP_MPS=(/mnt/llucillebuild /mnt/lucillebuild /mnt/boltzbuild /mnt/recoveryos)

run() { if [[ $DRY -eq 1 ]]; then echo "[dry-run] $*"; else "$@"; fi; }
die() { echo "ABORT: $*" >&2; exit 1; }
devof() { readlink -f "/dev/disk/by-partuuid/$1" 2>/dev/null || true; }

# ---- 0. every partition must be attached
declare -A DEV FS UUID
for p in "${PARTS[@]}"; do
  mp=${p%%|*}; pu=${p##*|}; d=$(devof "$pu")
  [[ -b ${d:-} ]] || die "$mp: no device with PARTUUID $pu is attached"
  DEV[$mp]=$d; FS[$mp]=$(lsblk -dno FSTYPE "$d"); UUID[$mp]=$(lsblk -dno UUID "$d")
  echo "found   $mp -> $d  (${FS[$mp]:-none}, ${UUID[$mp]:-no uuid})"
done

# ---- 1. optional reformat of D (NTFS -> ext4)
if [[ $REFORMAT -eq 1 ]]; then
  mp=/mnt/boltzbuild; d=${DEV[$mp]}
  if [[ ${FS[$mp]} == ext4 && ${UUID[$mp]} == "$BOLTZ_EXT4_UUID" ]]; then
    echo "reformat: $d is already ext4 $BOLTZ_EXT4_UUID - nothing to do"
  else
    [[ ${FS[$mp]} == ntfs ]] || die "$d is '${FS[$mp]}', not NTFS - refusing to format something unexpected"
    pk=$(lsblk -dno PKNAME "$d"); model=$(lsblk -dno MODEL "/dev/$pk" | tr -d ' ')
    size=$(lsblk -bdno SIZE "$d")
    [[ $model == CT2000X9* ]] || die "$d is on disk '$model', expected the Micron CT2000X9 build drive"
    (( size > 150000000000 && size < 180000000000 )) || die "$d is $size bytes, expected 150-180 GB (163 GiB)"
    # empty? (mount it if needed just to look - read-only)
    if findmnt -rn -S "$d" >/dev/null 2>&1; then look=$(findmnt -rn -S "$d" -o TARGET | grep -v autofs | head -1); else look=""; fi
    tmpm=0
    if [[ -z $look ]]; then look=$(mktemp -d); mount -o ro "$d" "$look" 2>/dev/null || { rmdir "$look"; die "cannot mount $d read-only to check that it is empty"; }; tmpm=1; fi
    n=$(ls -A "$look" 2>/dev/null | grep -vxE 'System Volume Information|\$RECYCLE\.BIN|lost\+found' | wc -l || true)
    [[ $tmpm -eq 1 ]] && { umount "$look"; rmdir "$look"; }
    [[ $n -eq 0 ]] || die "$d is NOT empty ($n top-level entries) - not formatting. Empty it yourself or ask first."
    echo; echo "About to REFORMAT $d  ($((size/1000000000)) GB, NTFS '$BOLTZ_LABEL', empty, on $model) -> ext4, label '$BOLTZ_LABEL', UUID $BOLTZ_EXT4_UUID"
    if [[ $DRY -eq 0 && $YES -eq 0 ]]; then
      read -r -p "Type the device path ($d) to confirm: " ans; [[ $ans == "$d" ]] || die "not confirmed"
    fi
    run systemctl stop mnt-boltzbuild.automount mnt-boltzbuild.mount || true
    findmnt -rn -S "$d" >/dev/null 2>&1 && run umount "$d"
    findmnt -rn -S "$d" >/dev/null 2>&1 && [[ $DRY -eq 0 ]] && die "$d is still mounted"
    run wipefs -a "$d"
    run mkfs.ext4 -F -q -L "$BOLTZ_LABEL" -U "$BOLTZ_EXT4_UUID" "$d"
    run udevadm settle
    FS[$mp]=ext4; UUID[$mp]=$BOLTZ_EXT4_UUID
    [[ $DRY -eq 1 ]] || { [[ $(lsblk -dno UUID "$d") == "$BOLTZ_EXT4_UUID" ]] || die "mkfs did not take"; echo "formatted $d ext4 $BOLTZ_EXT4_UUID"; }
  fi
fi

# ---- 2. fstab rows from what is really on each partition
fstab_row() { # mp
  local mp=$1 fs=${FS[$1]} u=${UUID[$1]}
  case $fs in
    ext4|btrfs) printf 'UUID=%s\t%s\t%s\tdefaults,nofail,x-systemd.automount\t0\t2\n' "$u" "$mp" "$fs" ;;
    ntfs)       printf 'UUID=%s\t%s\tntfs3\tuid=%s,gid=%s,umask=022,nofail,x-systemd.automount\t0\t0\n' "$u" "$mp" "$OWNER_UID" "$OWNER_GID" ;;
    *) die "$mp has unsupported filesystem '${fs:-none}'" ;;
  esac
}
tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
# drop: our header, old lines for these mountpoints, and the bare-number line an earlier version of this script
# wrote when it clobbered $LINES with the terminal height.
awk -v list="${DROP_MPS[*]}" -v hdr="$HEADER" '
  BEGIN { n = split(list, a, " "); for (i = 1; i <= n; i++) drop[a[i]] = 1 }
  $0 == hdr { next }
  /^[0-9]+[[:space:]]*$/ { next }
  /^[[:space:]]*#/ || NF < 2 { print; next }
  !($2 in drop) { print }' /etc/fstab > "$tmp"
{ echo "$HEADER"; for p in "${PARTS[@]}"; do fstab_row "${p%%|*}"; done; } >> "$tmp"
if [[ $DRY -eq 1 ]]; then echo; echo "--- /etc/fstab would end with:"; tail -n 4 "$tmp"
else
  cp -a /etc/fstab "/etc/fstab.bak-$(date +%Y%m%d-%H%M%S)"
  install -m 644 "$tmp" /etc/fstab
  # sanity: findmnt validates the whole file
  findmnt --verify --tab-file /etc/fstab >/dev/null 2>&1 || echo "note: 'findmnt --verify' reports issues (may be pre-existing); check with: findmnt --verify"
fi

# ---- 3. release the old typo'd mount, create mountpoints, mount
if findmnt -rn -M /mnt/llucillebuild >/dev/null 2>&1; then
  run umount /mnt/llucillebuild || die "/mnt/llucillebuild is busy (close shells/editors in it, then re-run)"
fi
[[ -d /mnt/llucillebuild ]] && ! findmnt -rn -M /mnt/llucillebuild >/dev/null 2>&1 && run rmdir /mnt/llucillebuild 2>/dev/null || true
for p in "${PARTS[@]}"; do run install -d "${p%%|*}"; done
run systemctl daemon-reload
for p in "${PARTS[@]}"; do
  mp=${p%%|*}
  run mount "$mp" 2>&1 || echo "FAILED  mount $mp" >&2
done

# ---- 4. a freshly formatted D belongs to the user, not root
if [[ $REFORMAT -eq 1 && $DRY -eq 0 ]] && findmnt -rn -M /mnt/boltzbuild -t ext4 >/dev/null 2>&1; then
  chown "$OWNER_UID:$OWNER_GID" /mnt/boltzbuild; chmod 755 /mnt/boltzbuild
fi

# ---- 5. result
if [[ $DRY -eq 0 ]]; then
  for p in "${PARTS[@]}"; do stat "${p%%|*}" >/dev/null 2>&1 || true; done
  echo; findmnt -rn -o TARGET,SOURCE,FSTYPE | grep -E '^/mnt/(lucillebuild|boltzbuild|recoveryos) ' | grep -v autofs || true
  echo; bash "$(dirname "$(readlink -f "$0")")/check_mounts.sh" || true
fi
