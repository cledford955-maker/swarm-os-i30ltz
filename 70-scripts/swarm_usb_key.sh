#!/usr/bin/env bash
# ── swarm_usb_key.sh ─────────────────────────────────────────────────────────
# SWARM OS Hardware USB Master Key Tool
# Detects, verifies, and provisions cheap USB flash drives as physical master keys
# to unlock SWARM OS or reset the 4-stone cipher.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

KEY_FILENAMES=("swarm_master.key" "swarm.key" ".swarm_master.key" ".swarm.key" "master.key" "lucille.key" "SWARM_MASTER.KEY" "SWARM.KEY")
DEFAULT_TOKEN="SWARM_MASTER_KEY_V1"
ETC_TOKEN_FILE="/etc/swarm_os/master_key.token"

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

  # Check mounts
  for mnt in "${mounts[@]}"; do
    if is_protected "$mnt"; then continue; fi
    for kn in "${KEY_FILENAMES[@]}"; do
      local kf="$mnt/$kn"
      local skf="$mnt/.swarm/$kn"
      for candidate in "$kf" "$skf"; do
        if [[ -f "$candidate" && -s "$candidate" ]]; then
          ok "Found Master Key: $candidate"
          echo "    Drive mount: $mnt"
          echo "    Key summary: $(head -n 5 "$candidate" | grep -v '^#' | head -n 2)"
          found=1
          break 2
        fi
      done
    done
  done

  if [[ $found -eq 0 ]]; then
    warn "No USB Master Key detected on active media mounts."
    return 1
  fi
  return 0
}

cmd_create() {
  local target_dir="${1:-}"
  local secret="${2:-$DEFAULT_TOKEN}"

  if [[ -z "$target_dir" ]]; then
    err "Usage: $0 create <mount_path_or_device> [secret_token]"
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
  log "Writing SWARM OS Master Key to: $key_file"

  local sha
  sha=$(echo -n "$secret" | sha256sum | awk '{print $1}')

  cat > "$key_file" << EOF
# SWARM OS HARDWARE MASTER KEY
# Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
# Plug this flash drive into any SWARM OS device to unlock or reset the stone cipher.
SYSTEM=SWARM_OS
KEY=$secret
SHA256=$sha
EOF
  chmod 644 "$key_file"

  ok "Master Key created successfully on $target_dir!"
  echo "    File: $key_file"
  echo "    Token: $secret"
  echo "    SHA-256: $sha"
  echo
  ok "You can now use this flash drive to unlock SWARM OS or reset the cipher."
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
