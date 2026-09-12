#!/usr/bin/env bash
# =============================================================================
# vm_boot_gate.sh — SWARM OS automated boot gate  (au2)
# v1.0.0 · 2026-09-12
#
# Boots a freshly built ISO headlessly in QEMU and refuses to let a broken
# image be called a release. Every check below is something that has actually
# gone wrong in this project before:
#
#   1. Kernel panics / never reaches userspace          -> serial console scan
#   2. A service crash-loops                            -> serial console scan
#   3. LucyServer never answers on :5000                -> HTTP /health probe
#   4. GamingAgent never answers on :8401               -> HTTP /health probe
#   5. Boot hangs forever (systemd-time-wait-sync, ...) -> hard timeout
#
# Exit 0 = the ISO boots and its services answer. Non-zero = do not ship it.
# The full serial log is always written, pass or fail — that is the artifact
# worth having when a boot goes wrong on real hardware.
#
# Usage:   ./vm_boot_gate.sh [/path/to.iso] [--timeout SECONDS] [--keep]
# Env:     SWARM_GATE_TIMEOUT (default 300), SWARM_GATE_MEM (default 4096)
# =============================================================================
set -euo pipefail

LUCY="/mnt/Lucy"
OUT_DIR="$LUCY/10-releases"
LOG_DIR="$LUCY/logs"
TIMEOUT="${SWARM_GATE_TIMEOUT:-300}"
MEM="${SWARM_GATE_MEM:-4096}"
KEEP_DISK=0
ISO_PATH=""

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
ok()   { echo -e "${GREEN}✓ $*${NC}"; }
bad()  { echo -e "${RED}✗ $*${NC}" >&2; }
info() { echo -e "${CYAN}  $*${NC}"; }

while [ $# -gt 0 ]; do
    case "$1" in
        --timeout) TIMEOUT="$2"; shift 2 ;;
        --keep)    KEEP_DISK=1; shift ;;
        -h|--help) sed -n '3,25p' "$0"; exit 0 ;;
        *)         ISO_PATH="$1"; shift ;;
    esac
done

[ -n "$ISO_PATH" ] || ISO_PATH="$OUT_DIR/swarm-os-latest.iso"
[ -f "$ISO_PATH" ] || { bad "ISO not found: $ISO_PATH"; exit 2; }

command -v qemu-system-x86_64 >/dev/null 2>&1 || { bad "qemu-system-x86_64 not installed (pacman -S qemu-full)"; exit 2; }
command -v qemu-img          >/dev/null 2>&1 || { bad "qemu-img not installed (pacman -S qemu-full)"; exit 2; }
command -v curl              >/dev/null 2>&1 || { bad "curl not installed"; exit 2; }

STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p "$LOG_DIR"
SERIAL_LOG="$LOG_DIR/boot-gate-$STAMP.log"
DISK="$(mktemp -u -t swarm-gate-XXXXXX).qcow2"
SSH_PORT=22222
LUCY_PORT=15000
GAME_PORT=18401

echo -e "\n${CYAN}${BOLD}======================================================================${NC}"
echo -e "${CYAN}${BOLD}  SWARM OS :: AUTOMATED BOOT GATE  v1.0.0 · $(date +%Y-%m-%d)${NC}"
echo -e "${CYAN}${BOLD}======================================================================${NC}"
info "ISO:     $ISO_PATH"
info "Timeout: ${TIMEOUT}s"
info "Serial:  $SERIAL_LOG"

qemu-img create -f qcow2 "$DISK" 16G >/dev/null

QEMU_ACCEL=()
if [ -w /dev/kvm ]; then
    QEMU_ACCEL=(-enable-kvm -cpu host)
    info "KVM:     enabled"
else
    QEMU_ACCEL=(-cpu max)
    info "KVM:     unavailable — TCG emulation, expect a slower boot"
fi

UEFI=()
OVMF_CODE="/usr/share/edk2-ovmf/x64/OVMF_CODE.4m.fd"
OVMF_VARS_SRC="/usr/share/edk2-ovmf/x64/OVMF_VARS.4m.fd"
GATE_VARS="$(mktemp -u -t swarm-gate-vars-XXXXXX).fd"
if [ -f "$OVMF_CODE" ] && [ -f "$OVMF_VARS_SRC" ]; then
    cp "$OVMF_VARS_SRC" "$GATE_VARS"
    UEFI=(-drive "if=pflash,format=raw,readonly=on,file=$OVMF_CODE"
          -drive "if=pflash,format=raw,file=$GATE_VARS")
    info "Firmware: UEFI (OVMF)"
else
    info "Firmware: BIOS (OVMF not installed — real hardware boots UEFI, so this"
    info "          gate is weaker than it should be; pacman -S edk2-ovmf)"
fi

cleanup() {
    [ -n "${QEMU_PID:-}" ] && kill -0 "$QEMU_PID" 2>/dev/null && kill -TERM "$QEMU_PID" 2>/dev/null || true
    sleep 1
    [ -n "${QEMU_PID:-}" ] && kill -0 "$QEMU_PID" 2>/dev/null && kill -KILL "$QEMU_PID" 2>/dev/null || true
    [ "$KEEP_DISK" -eq 0 ] && rm -f "$DISK" "$GATE_VARS" 2>/dev/null || true
}
trap cleanup EXIT

qemu-system-x86_64 \
    "${QEMU_ACCEL[@]}" \
    -m "$MEM" -smp "$(nproc)" \
    "${UEFI[@]}" \
    -display none \
    -serial "file:$SERIAL_LOG" \
    -device virtio-net-pci,netdev=net0 \
    -netdev "user,id=net0,hostfwd=tcp::${SSH_PORT}-:22,hostfwd=tcp::${LUCY_PORT}-:5000,hostfwd=tcp::${GAME_PORT}-:8401" \
    -drive "file=$DISK,if=virtio,format=qcow2,cache=writeback" \
    -cdrom "$ISO_PATH" \
    -boot order=d \
    -no-reboot \
    >/dev/null 2>&1 &
QEMU_PID=$!

# --- watch the boot ----------------------------------------------------------
PANIC_RE='Kernel panic|BUG: unable to handle|Attempted to kill init|end Kernel panic'
LOOP_RE='Start request repeated too quickly|Failed to start|entered failed state'
EMERG_RE='Entering emergency mode|You are in emergency mode|Cannot open access to console'

lucy_up=0; game_up=0; verdict=""
start=$SECONDS
echo -e "\n${CYAN}  watching boot …${NC}"

while [ $((SECONDS - start)) -lt "$TIMEOUT" ]; do
    if ! kill -0 "$QEMU_PID" 2>/dev/null; then
        verdict="QEMU exited after $((SECONDS - start))s — the guest shut down or triple-faulted before the gate passed"
        break
    fi
    if [ -s "$SERIAL_LOG" ]; then
        if grep -qE "$PANIC_RE" "$SERIAL_LOG"; then
            verdict="kernel panic on the serial console"; break
        fi
        if grep -qE "$EMERG_RE" "$SERIAL_LOG"; then
            verdict="guest dropped into emergency mode"; break
        fi
        if grep -qE "$LOOP_RE" "$SERIAL_LOG"; then
            verdict="a unit crash-looped or failed to start: $(grep -oE "$LOOP_RE.*" "$SERIAL_LOG" | head -3 | tr '\n' ';')"
            break
        fi
    fi
    [ "$lucy_up" -eq 0 ] && curl -fsS --max-time 3 "http://127.0.0.1:${LUCY_PORT}/health" >/dev/null 2>&1 \
        && { lucy_up=1; ok "LucyServer answered /health on :5000  (${SECONDS}s)"; }
    [ "$game_up" -eq 0 ] && curl -fsS --max-time 3 "http://127.0.0.1:${GAME_PORT}/health" >/dev/null 2>&1 \
        && { game_up=1; ok "GamingAgent answered /health on :8401 (${SECONDS}s)"; }
    [ "$lucy_up" -eq 1 ] && [ "$game_up" -eq 1 ] && break
    sleep 3
done

elapsed=$((SECONDS - start))

# --- verdict -----------------------------------------------------------------
echo
if [ -n "$verdict" ]; then
    bad "BOOT GATE FAILED after ${elapsed}s — $verdict"
elif [ "$lucy_up" -eq 1 ] && [ "$game_up" -eq 1 ]; then
    echo -e "${GREEN}${BOLD}  BOOT GATE PASSED — ISO reached a healthy userspace in ${elapsed}s.${NC}"
    echo -e "${CYAN}  Serial log: $SERIAL_LOG${NC}"
    echo -e "${YELLOW}  Note: this proves the services came up. It does NOT prove the kiosk${NC}"
    echo -e "${YELLOW}  shell rendered — QEMU has no GPU here. Confirm the UI on hardware.${NC}"
    exit 0
else
    [ "$lucy_up" -eq 0 ] && bad "LucyServer never answered /health on :5000"
    [ "$game_up" -eq 0 ] && bad "GamingAgent never answered /health on :8401"
    bad "BOOT GATE FAILED — timed out after ${elapsed}s of ${TIMEOUT}s"
fi

echo -e "\n${YELLOW}  last 40 lines of serial console:${NC}"
tail -n 40 "$SERIAL_LOG" 2>/dev/null | sed 's/^/    /' || echo "    (serial log is empty — the guest produced no console output at all)"
echo -e "\n${CYAN}  Full serial log: $SERIAL_LOG${NC}"
exit 1
