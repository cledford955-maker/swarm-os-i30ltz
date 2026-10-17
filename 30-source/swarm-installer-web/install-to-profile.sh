#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║  install-to-profile.sh                                              ║
# ║  Version: 1.0.0 | Date: 2026-10-05                                  ║
# ║  Installs the SWARM_OS graphical installer into the archiso profile.║
# ║                                                                      ║
# ║  Idempotent and non-destructive: never overwrites an existing file   ║
# ║  without backing it up to <file>.bak-YYYYMMDD-HHMM first, and only   ║
# ║  appends to packages.x86_64 when an entry is genuinely absent.       ║
# ║                                                                      ║
# ║  Run as your normal user from this directory:                        ║
# ║     bash install-to-profile.sh [--profile DIR] [--dry-run]           ║
# ╚══════════════════════════════════════════════════════════════════════╝
set -euo pipefail

VERSION="1.0.0"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILE="/mnt/Lucy/40-iso-profile/swarm_os_iso_profile"
DRY=0
STAMP="$(date +%Y%m%d-%H%M)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    -h|--help) sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

C_OK=$'\033[0;32m'; C_WARN=$'\033[1;33m'; C_ERR=$'\033[0;31m'
C_INFO=$'\033[0;36m'; C_NC=$'\033[0m'
ok()   { echo "${C_OK}  ✓${C_NC} $*"; }
warn() { echo "${C_WARN}  ⚠${C_NC} $*"; }
err()  { echo "${C_ERR}  ✗${C_NC} $*" >&2; }
step() { echo; echo "${C_INFO}── $*${C_NC}"; }

run() { if [[ $DRY -eq 1 ]]; then echo "      [dry-run] $*"; else "$@"; fi; }

echo
echo "  SWARM_OS graphical installer → archiso profile"
echo "  installer v$VERSION   profile: $PROFILE"
[[ $DRY -eq 1 ]] && warn "DRY RUN — nothing will be written"

# ── Preflight ─────────────────────────────────────────────────────────
step "Preflight"
AIROOTFS="$PROFILE/airootfs"
PKGLIST="$PROFILE/packages.x86_64"

[[ -d "$PROFILE" ]]  || { err "profile not found: $PROFILE"; exit 1; }
[[ -d "$AIROOTFS" ]] || { err "airootfs not found: $AIROOTFS"; exit 1; }
[[ -f "$PKGLIST" ]]  || { err "packages.x86_64 not found: $PKGLIST"; exit 1; }
ok "profile layout looks right"

if [[ ! -f "$AIROOTFS/usr/local/bin/install_swarm_os.sh" ]]; then
  err "install_swarm_os.sh missing from the profile."
  err "The GUI is a front-end for that script — it cannot work without it."
  exit 1
fi
ok "backend script present: airootfs/usr/local/bin/install_swarm_os.sh"

# Confirm the backend really does support the flags we drive it with.
for flag in -- "--non-interactive" "--password-file" "--disk"; do
  [[ "$flag" == "--" ]] && continue
  if ! grep -q -- "$flag" "$AIROOTFS/usr/local/bin/install_swarm_os.sh"; then
    err "backend script does not accept $flag — refusing to wire up a GUI"
    err "that would call it incorrectly."
    exit 1
  fi
done
ok "backend accepts --disk / --non-interactive / --password-file"

# ── Copy payload ──────────────────────────────────────────────────────
step "Installing installer payload"
LIB="$AIROOTFS/usr/local/lib/swarm-installer"
run mkdir -p "$LIB/web" "$AIROOTFS/usr/local/bin" \
             "$AIROOTFS/usr/share/applications" \
             "$AIROOTFS/etc/sudoers.d"

backup_if_exists() {
  local f="$1"
  if [[ -f "$f" ]]; then
    run cp -a "$f" "$f.bak-$STAMP"
    warn "existing $(basename "$f") backed up → $(basename "$f").bak-$STAMP"
  fi
}

backup_if_exists "$LIB/server.py"
run install -Dm755 "$SRC/server.py"        "$LIB/server.py"
ok "server.py → usr/local/lib/swarm-installer/"

backup_if_exists "$LIB/web/index.html"
run install -Dm644 "$SRC/web/index.html"   "$LIB/web/index.html"
ok "web/index.html → usr/local/lib/swarm-installer/web/"

backup_if_exists "$AIROOTFS/usr/local/bin/swarm-installer"
run install -Dm755 "$SRC/bin/swarm-installer" "$AIROOTFS/usr/local/bin/swarm-installer"
ok "swarm-installer → usr/local/bin/"

# ── Desktop entry ─────────────────────────────────────────────────────
step "Desktop entry"
DESKTOP="$AIROOTFS/usr/share/applications/swarm-installer.desktop"
backup_if_exists "$DESKTOP"
if [[ $DRY -eq 0 ]]; then
  cat > "$DESKTOP" <<'EOF'
[Desktop Entry]
Type=Application
Version=1.0
Name=Install SWARM OS
GenericName=System Installer
Comment=Install SWARM OS to a disk on this machine
Exec=/usr/local/bin/swarm-installer
Icon=swarm-install
Terminal=false
Categories=System;Settings;
Keywords=install;swarm;setup;
StartupNotify=true
EOF
else
  echo "      [dry-run] write $DESKTOP"
fi
ok "Install SWARM OS .desktop entry written"

# Reuse the hornet icon already in the GRUB theme if it is there.
ICON_SRC="$PROFILE/grub/themes/swarm_os/icons/swarm-install.png"
ICON_DST="$AIROOTFS/usr/share/icons/hicolor/256x256/apps/swarm-install.png"
if [[ -f "$ICON_SRC" ]]; then
  run mkdir -p "$(dirname "$ICON_DST")"
  run cp -n "$ICON_SRC" "$ICON_DST" 2>/dev/null || true
  ok "icon sourced from existing GRUB theme"
else
  warn "no swarm-install.png in the GRUB theme — entry will use a fallback icon"
fi

# ── Packages ──────────────────────────────────────────────────────────
step "Package list"
# python is needed for the backend; a browser is needed for the front-end.
# cage gives a true kiosk on Wayland without a full desktop.
NEEDED=(python chromium cage)
ADDED=()
for p in "${NEEDED[@]}"; do
  if grep -qx "$p" "$PKGLIST"; then
    ok "$p already in packages.x86_64"
  else
    ADDED+=("$p")
  fi
done

if [[ ${#ADDED[@]} -gt 0 ]]; then
  backup_if_exists "$PKGLIST"
  if [[ $DRY -eq 0 ]]; then
    {
      echo ""
      echo "# ── SWARM_OS graphical installer (added $STAMP) ──"
      printf '%s\n' "${ADDED[@]}"
    } >> "$PKGLIST"
  fi
  ok "appended to packages.x86_64: ${ADDED[*]}"
else
  ok "no package changes needed"
fi

# ── Sudoers ───────────────────────────────────────────────────────────
step "Privilege rule"
SUDO_EXISTING="$AIROOTFS/etc/sudoers.d/20-swarm-installer"
SUDO_NEW="$AIROOTFS/etc/sudoers.d/21-swarm-installer-gui"

if [[ -f "$SUDO_EXISTING" ]]; then
  ok "existing 20-swarm-installer left untouched"
  if grep -q "install_swarm_os.sh" "$SUDO_EXISTING"; then
    ok "it already grants the installer script — no new rule needed"
    SKIP_SUDO=1
  fi
fi

if [[ "${SKIP_SUDO:-0}" -ne 1 ]]; then
  backup_if_exists "$SUDO_NEW"
  if [[ $DRY -eq 0 ]]; then
    cat > "$SUDO_NEW" <<'EOF'
# SWARM_OS graphical installer — live media only.
# The GUI runs as the live user and needs exactly two privileged actions:
# running the installer, and rebooting when it finishes. Nothing else.
# This file is intentionally NOT shipped to an installed system; it exists
# only inside the live ISO's airootfs.
%wheel ALL=(root) NOPASSWD: /usr/local/bin/install_swarm_os.sh
%wheel ALL=(root) NOPASSWD: /usr/bin/systemctl reboot
EOF
    chmod 0440 "$SUDO_NEW"
  fi
  ok "21-swarm-installer-gui written (0440, scoped to two commands)"
fi

# ── Autostart ─────────────────────────────────────────────────────────
step "Autostart hint"
SWAY_CFG="$AIROOTFS/etc/sway/config"
AUTOSTART_LINE='exec --no-startup-id /usr/local/bin/swarm-installer'
if [[ -f "$SWAY_CFG" ]]; then
  if grep -q "swarm-installer" "$SWAY_CFG"; then
    ok "sway config already references swarm-installer"
  else
    warn "sway config found but does not autostart the installer."
    echo "        To launch it automatically on live boot, add:"
    echo "            $AUTOSTART_LINE"
    echo "        to $SWAY_CFG"
  fi
else
  warn "no airootfs/etc/sway/config — launch the installer from its"
  echo "        desktop entry, or add an autostart line to your session."
fi

# ── Summary ───────────────────────────────────────────────────────────
step "Summary"
cat <<EOF
  Installed into: $PROFILE

    airootfs/usr/local/lib/swarm-installer/server.py
    airootfs/usr/local/lib/swarm-installer/web/index.html
    airootfs/usr/local/bin/swarm-installer
    airootfs/usr/share/applications/swarm-installer.desktop
    airootfs/etc/sudoers.d/21-swarm-installer-gui   (if needed)
    packages.x86_64                                 (python, chromium, cage)

  Test the UI on this machine WITHOUT building an ISO:

    SWARM_INSTALLER_DRYRUN=1 python3 $SRC/server.py
      → open the printed URL in a browser

  Then build the ISO with the canonical builder:

    /mnt/Lucy/70-scripts/build_swarm_iso.sh

EOF
[[ $DRY -eq 1 ]] && warn "This was a DRY RUN — re-run without --dry-run to apply."
echo
