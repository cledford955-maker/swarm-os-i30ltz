#!/usr/bin/env bash
# DESTRUCTIVE: reformat /dev/sda4 (label swarm-build) as ext4, mount at /mnt/swarmbuild, rsync the project into it.
# Run: sudo bash /tmp/wipe_and_seed_swarmbuild.sh   (run install_fstab_mounts.sh first)
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "run with sudo" >&2; exit 1; }
DEV=/dev/sda4
SRC=${1:-/mnt/Lucy}
[[ -d $SRC/70-scripts ]] || { echo "source $SRC is not the project" >&2; exit 1; }
[[ $(lsblk -no LABEL "$DEV") == swarm-build ]] || { echo "$DEV is not labelled swarm-build; aborting" >&2; exit 1; }
[[ $(findmnt -no SOURCE "$SRC") != "$DEV" ]] || { echo "source lives on $DEV; aborting" >&2; exit 1; }
echo "This ERASES everything on $DEV ($(lsblk -no SIZE,LABEL "$DEV" | head -1))."
read -rp "Type ERASE to continue: " ans; [[ $ans == ERASE ]] || { echo aborted; exit 1; }

findmnt -rn -S "$DEV" -o TARGET | sort -r | while read -r t; do umount "$t"; done
mkfs.ext4 -F -L swarm-build "$DEV"
install -d /mnt/swarmbuild
mount "$DEV" /mnt/swarmbuild
chown "${SUDO_UID:-1000}:${SUDO_GID:-1000}" /mnt/swarmbuild
rsync -aHAX --info=progress2 "$SRC"/ /mnt/swarmbuild/
echo "seeded /mnt/swarmbuild from $SRC"; df -h /mnt/swarmbuild | tail -1
