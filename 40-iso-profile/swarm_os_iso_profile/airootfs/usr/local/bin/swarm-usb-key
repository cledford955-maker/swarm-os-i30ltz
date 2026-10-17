#!/usr/bin/env bash
# ── swarm_usb_key.sh ─────────────────────────────────────────────────────────
# SWARM OS Hardware USB Master Key Tool
# Detects, verifies, and provisions cheap USB flash drives as physical master keys
# to unlock SWARM OS or reset the 4-stone cipher.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

KEY_FILENAMES=("swarm_master.key" "swarm.key" ".swarm_master.key" ".swarm.key" "master.key" "lucille.key" "SWARM_MASTER.KEY" "SWARM.KEY" "MASTER.KEY")
# Published in source (old default), so it is refused as a secret and never unlocks anything.
PUBLIC_TOKEN="SWARM_MASTER_KEY_V1"
# SHA-256 of the one registered secret; the lock screen reads the same file
# (usb_master_key_service.dart keyHashFile). Only the hash, never the secret, is kept here.
HASH_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/swarm_os/usb_master_key.sha256"

log()  { echo -e "\033[1;36m[swarm-usb-key]\033[0m $*"; }
ok()   { echo -e "\033[1;32m[+] \033[0m $*"; }
warn() { echo -e "\033[1;33m[!] \033[0m $*"; }
err()  { echo -e "\033[1;31m[-] \033[0m $*" >&2; }

is_protected() {
  local p="$1"
  case "$p" in
    /|/boot|/boot/*|/mnt/Lucy|/mnt/lucy|*lucy-master*|/mnt/swarmbuild|/mnt/archive|/mnt/downloads|/mnt/recoverybuild|/mnt/boltzbuild|/mnt/brains|/mnt/recoveryos|/mnt/swarm)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

cmd_list() {
  log "Scanning for connected USB flash drives..."
  local json
  json=$(lsblk -J -o NAME,MOUNTPOINT,RM,TRAN,FSTYPE,LABEL,UUID,PATH,MODEL,SIZE 2>/dev/null || echo "{}")
  python3 -c '
import sys, json, os

data = json.loads(sys.stdin.read())
key_names = ["swarm_master.key", "swarm.key", ".swarm_master.key", "master.key", "lucille.key", "SWARM_MASTER.KEY", "SWARM.KEY"]
drives = []

for dev in data.get("blockdevices", []):
    is_usb = dev.get("rm") is True or dev.get("tran") == "usb"
    if not is_usb: continue
    model = dev.get("model") or "Flash Drive"
    
    def check_node(n):
        mount = n.get("mountpoint")
        path = n.get("path")
        label = n.get("label") or ""
        size = n.get("size") or ""
        fstype = n.get("fstype") or ""
        if not path: return
        has_key = False
        if mount and os.path.exists(mount):
            for kn in key_names:
                if os.path.exists(os.path.join(mount, kn)) or os.path.exists(os.path.join(mount, ".swarm", kn)):
                    has_key = True
                    break
        drives.append({
            "path": path,
            "mount": mount,
            "label": label,
            "model": model.strip(),
            "size": size,
            "fstype": fstype,
            "has_key": has_key
        })

    children = dev.get("children", [])
    if children:
        for c in children: check_node(c)
    else:
        check_node(dev)

if not drives:
    print("  No USB drives found. Insert a USB flash drive and try again.")
else:
    for d in drives:
        status = "[\033[1;32mMASTER KEY PRESENT\033[0m]" if d["has_key"] else "[\033[1;30mNO KEY\033[0m]"
        mnt = d["mount"] or "(unmounted)"
        path = d["path"]
        size = d["size"]
        fstype = d["fstype"]
        label = d["label"]
        model = d["model"]
        print(f"  * {path} ({size}, {fstype}) - Label: \"{label}\" Model: \"{model}\" -> {mnt} {status}")
' <<< "$json"
}

cmd_scan() {
  log "Scanning mounted and removable drives for USB Master Key..."
  local found=0
  local mounts=()

  # 1. From /proc/mounts
  while read -r dev mnt rest; do
    if [[ "$mnt" =~ ^/(run/)?media/ ]]; then
      mounts+=("$mnt")
    fi
  done < /proc/mounts

  local want=""
  [[ -f "$HASH_FILE" ]] && want="$(tr -d '[:space:]' < "$HASH_FILE" | tr 'A-F' 'a-f')"
  if [[ ! "$want" =~ ^[0-9a-f]{64}$ ]]; then
    warn "No USB key is registered on this machine ($HASH_FILE), so no key file can unlock it."
    want=""
  fi

  # Check mounts (same rules as the lock screen: real files only, no symlinks, exact KEY= line)
  for mnt in "${mounts[@]}"; do
    if is_protected "$mnt"; then continue; fi
    for kn in "${KEY_FILENAMES[@]}"; do
      for candidate in "$mnt/$kn" "$mnt/.swarm/$kn"; do
        [[ -f "$candidate" && ! -L "$candidate" && ! -L "$mnt/.swarm" ]] || continue
        if [[ -n "$want" ]] && key_file_matches "$candidate" "$want"; then
          ok "Valid master key for this machine: $candidate"
          found=1
        else
          warn "Key file present but NOT valid for this machine: $candidate"
        fi
      done
    done
  done

  if [[ $found -eq 0 ]]; then
    warn "No valid USB Master Key detected on active media mounts."
    return 1
  fi
  return 0
}

# key_file_matches FILE HASH: true when FILE has a KEY=<secret> line whose sha256 is HASH.
key_file_matches() {
  local f="$1" want="$2" line secret
  [[ $(stat -c %s "$f") -le 4096 ]] || return 1
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"; line="${line%"${line##*[![:space:]]}"}"
    [[ "$line" == KEY=* ]] || continue
    secret="${line#KEY=}"
    secret="${secret#"${secret%%[![:space:]]*}"}"
    [[ -n "$secret" && "$secret" != "$PUBLIC_TOKEN" ]] || continue
    [[ "$(printf '%s' "$secret" | sha256sum | awk '{print $1}')" == "$want" ]] && return 0
  done < "$f"
  return 1
}

cmd_create() {
  local target_dir="${1:-}"
  local secret="${2:-}"

  if [[ -z "$target_dir" ]]; then
    err "Usage: $0 create <mount_path_or_device> [secret_token]"
    exit 1
  fi
  if [[ $EUID -eq 0 ]]; then
    err "Run this as your normal user: the lock screen reads the key hash from your own ~/.config."
    exit 1
  fi
  if [[ -z "$secret" ]]; then
    secret="$(od -An -tx1 -N32 /dev/urandom | tr -d ' \n')"
  elif [[ "$secret" == "$PUBLIC_TOKEN" || ${#secret} -lt 16 || "$secret" =~ [[:space:]] ]]; then
    err "The secret must be private, at least 16 characters, with no spaces (or leave it out for a random one)."
    exit 1
  fi

  # If a device node was given (/dev/sdX1), mount it if not mounted
  if [[ -b "$target_dir" ]]; then
    local mnt
    mnt=$(lsblk -no MOUNTPOINT "$target_dir" | head -n 1)
    if [[ -z "$mnt" ]]; then
      log "Mounting $target_dir via udisksctl..."
      local out
      out=$(udisksctl mount -b "$target_dir" --no-user-interaction)
      mnt=$(echo "$out" | grep -o 'at /.*' | sed 's/at //;s/\.$//')
    fi
    target_dir="$mnt"
  fi

  if [[ ! -d "$target_dir" ]]; then
    err "Target directory '$target_dir' does not exist."
    exit 1
  fi

  if is_protected "$target_dir"; then
    err "Refusing to create master key on protected system mount: $target_dir"
    exit 1
  fi

  local key_file="$target_dir/swarm_master.key"
  if [[ -L "$key_file" || ( -e "$key_file" && ! -f "$key_file" ) ]]; then
    err "Refusing to write: $key_file is not a regular file."
    exit 1
  fi
  log "Writing SWARM OS Master Key to: $key_file"

  local sha
  sha=$(printf '%s' "$secret" | sha256sum | awk '{print $1}')

  (umask 077; cat > "$key_file" << EOF
# SWARM OS HARDWARE MASTER KEY
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
# Unlocks the lock screen of the SWARM OS machine that made it. Keep it private.
SYSTEM=SWARM_OS
KEY=$secret
EOF
  )
  sync -f "$key_file" 2>/dev/null || sync
  if ! key_file_matches "$key_file" "$sha"; then
    err "The key file did not read back correctly; the old key (if any) is still the valid one."
    exit 1
  fi

  # Register it: one USB key file is valid at a time, so this retires any older stick.
  mkdir -p "$(dirname "$HASH_FILE")"
  printf '%s\n' "$sha" > "$HASH_FILE.tmp"
  mv -f "$HASH_FILE.tmp" "$HASH_FILE"

  ok "Master Key created on $target_dir and registered for this machine."
  echo "    File: $key_file"
  echo "    Registered hash: $HASH_FILE"
  echo "    Any older USB key file no longer unlocks this machine."
}

case "${1:-}" in
  list|ls)
    cmd_list
    ;;
  scan)
    cmd_scan
    ;;
  create|make)
    shift
    cmd_create "$@"
    ;;
  *)
    echo "SWARM OS Hardware USB Master Key Tool"
    echo "Usage:"
    echo "  $0 list                     List attached USB drives and master key status"
    echo "  $0 scan                     Scan for an active USB master key"
    echo "  $0 create <target_dir|dev>  Write master key file to a flash drive"
    ;;
esac
