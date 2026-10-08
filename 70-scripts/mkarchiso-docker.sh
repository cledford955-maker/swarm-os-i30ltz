#!/usr/bin/env bash
# mkarchiso-docker.sh — drop-in replacement for mkarchiso on non-Arch hosts.
# Runs mkarchiso inside an Arch Linux Docker container with the necessary
# bind mounts. Called by build_swarm_iso.sh when the host lacks mkarchiso.
#
# Usage: same as mkarchiso — this script forwards all arguments.
#   mkarchiso-docker.sh -v -w /mnt/Lucy/swarm_os_build_work -o /output/dir /mnt/Lucy/40-iso-profile/swarm_os_iso_profile
set -euo pipefail

CONTAINER_IMAGE="archlinux:latest"

# Parse the arguments to find -w (work dir), -o (output dir), and the profile dir (last arg).
WORK_DIR=""
OUT_DIR=""
PROFILE_DIR=""
ARGS=("$@")

i=0
while [ $i -lt ${#ARGS[@]} ]; do
    case "${ARGS[$i]}" in
        -w) WORK_DIR="${ARGS[$((i+1))]}"; i=$((i+2)) ;;
        -o) OUT_DIR="${ARGS[$((i+1))]}"; i=$((i+2)) ;;
        *)  PROFILE_DIR="${ARGS[$i]}"; i=$((i+1)) ;;
    esac
done

if [ -z "$WORK_DIR" ] || [ -z "$OUT_DIR" ] || [ -z "$PROFILE_DIR" ]; then
    echo "Could not parse mkarchiso arguments: -w WORK -o OUT PROFILE" >&2
    echo "Got: $*" >&2
    exit 1
fi

# Ensure the container image is available
if ! docker image inspect "$CONTAINER_IMAGE" &>/dev/null; then
    echo "[mkarchiso-docker] Pulling $CONTAINER_IMAGE..."
    docker pull "$CONTAINER_IMAGE"
fi

echo "[mkarchiso-docker] Running mkarchiso inside Arch container"
echo "  Profile: $PROFILE_DIR"
echo "  Work:    $WORK_DIR"
echo "  Output:  $OUT_DIR"

exec docker run --rm --privileged \
    -v "$PROFILE_DIR:$PROFILE_DIR:ro" \
    -v "$WORK_DIR:$WORK_DIR" \
    -v "$OUT_DIR:$OUT_DIR" \
    -v /mnt/Lucy:/mnt/Lucy:ro \
    "$CONTAINER_IMAGE" \
    bash -c "
        pacman -Sy --noconfirm --needed archiso grub &&
        mkarchiso -v -w '$WORK_DIR' -o '$OUT_DIR' '$PROFILE_DIR'
    "
