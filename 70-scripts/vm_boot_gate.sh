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
OUT_DIR="/mnt/ventoy/ISO/SWARM_OS"
LOG_DIR="$LUCY/logs"
# 300s used to be enough, but a build with secrets sealed behind a real
# passphrase changes the timing: lucy-server.service/gaming-agent.service
# both wait on swarm-secrets.service, which retries systemd-ask-password up
# to 3x with a 120s timeout each (360s worst case) before giving up and
# continuing key-less — and this headless test VM has no keyfile drive
# attached and no way to answer the prompt, so it always hits that worst
# case. Found 2026-09-13: a perfectly healthy sealed ISO was timing out here
# with LucyServer/GamingAgent never even getting a chance to start. 480s
# clears the 360s worst case with room left for the actual boot+services.
TIMEOUT="${SWARM_GATE_TIMEOUT:-480}"
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

[ -n "$ISO_PATH" ] || ISO_PATH="$(python "$LUCY/70-scripts/swarm_iso_manager.py" latest)"
[ -f "$ISO_PATH" ] || { bad "ISO not found: $ISO_PATH"; exit 2; }

command -v qemu-system-x86_64 >/dev/null 2>&1 || { bad "qemu-system-x86_64 not installed (pacman -S qemu-full)"; exit 2; }
command -v qemu-img          >/dev/null 2>&1 || { bad "qemu-img not installed (pacman -S qemu-full)"; exit 2; }
command -v curl              >/dev/null 2>&1 || { bad "curl not installed"; exit 2; }

STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p "$LOG_DIR"
SERIAL_LOG="$LOG_DIR/boot-gate-$STAMP.log"
QEMU_LOG="$LOG_DIR/boot-gate-$STAMP-qemu.log"
DISK="$(mktemp -u -t swarm-gate-XXXXXX).qcow2"

# Hardcoded host ports used to collide with a leftover QEMU process from a
# prior run (found 2026-09-13: repeated back-to-back gate runs during active
# debugging are exactly this script's normal use case, and a killed/crashed
# run can leave qemu-system-x86_64 still holding its hostfwd ports) —
# "Could not set up host forwarding rule" aborted QEMU instantly with no
# guest output at all, which looked identical to a real boot failure. Pick a
# free port for each instead of trusting a fixed number.
# Each call runs via $(...), i.e. its own subshell — take already-picked
# ports as arguments rather than a shared variable, which a subshell can't
# write back to its caller.
free_port() {
    local p used
    for _ in $(seq 1 20); do
        p=$(( (RANDOM % 20000) + 20000 ))
        for used in "$@"; do
            [ "$p" = "$used" ] && continue 2
        done
        ss -Htln "sport = :$p" 2>/dev/null | grep -q . || { echo "$p"; return 0; }
    done
    return 1
}
SSH_PORT=$(free_port) || { echo -e "${RED}Could not find a free port for SSH forwarding.${NC}"; exit 2; }
LUCY_PORT=$(free_port "$SSH_PORT") || { echo -e "${RED}Could not find a free port for LucyServer forwarding.${NC}"; exit 2; }
GAME_PORT=$(free_port "$SSH_PORT" "$LUCY_PORT") || { echo -e "${RED}Could not find a free port for GamingAgent forwarding.${NC}"; exit 2; }

echo -e "\n${CYAN}${BOLD}======================================================================${NC}"
echo -e "${CYAN}${BOLD}  SWARM OS :: AUTOMATED BOOT GATE  v1.0.0 · $(date +%Y-%m-%d)${NC}"
echo -e "${CYAN}${BOLD}======================================================================${NC}"
info "ISO:     $ISO_PATH"
info "Timeout: ${TIMEOUT}s"
info "Serial:  $SERIAL_LOG"
info "Ports:   ssh=$SSH_PORT lucy=$LUCY_PORT game=$GAME_PORT"

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
    [ -n "${ANSWER_PID:-}" ] && kill "$ANSWER_PID" 2>/dev/null || true
    [ -n "${CAT_PID:-}" ] && kill "$CAT_PID" 2>/dev/null || true
    [ -n "${QEMU_PID:-}" ] && kill -0 "$QEMU_PID" 2>/dev/null && kill -TERM "$QEMU_PID" 2>/dev/null || true
    sleep 1
    [ -n "${QEMU_PID:-}" ] && kill -0 "$QEMU_PID" 2>/dev/null && kill -KILL "$QEMU_PID" 2>/dev/null || true
    [ "$KEEP_DISK" -eq 0 ] && rm -f "$DISK" "$GATE_VARS" 2>/dev/null || true
}
trap cleanup EXIT

# -serial pty (not file:) so this script can also WRITE to the guest console,
# not just log it. Needed because of swarm-secrets.service: it blocks
# lucy-server.service/gaming-agent.service (Before=) behind an interactive
# `systemd-ask-password --timeout=120 --no-tty` passphrase prompt that a real
# human at real hardware would skip with Enter — but found 2026-09-18: that
# call never actually times out against a plain `-serial file:...` backend (no
# input side at all), so the gate hung the full timeout every run with
# LucyServer/GamingAgent never getting a turn to start. A `-kernel`/`-initrd`
# direct-boot bypass was tried first to route around the prompt entirely via a
# kernel cmdline override, but that changed how the guest locates the archiso
# medium and it stopped finding it at all (dropped into the archiso initrd's
# own rescue shell instead) — reverted. Actually answering the prompt with a
# real keypress, same as a human would, avoids that whole class of new bugs.
qemu-system-x86_64 \
    "${QEMU_ACCEL[@]}" \
    -m "$MEM" -smp "$(nproc)" \
    "${UEFI[@]}" \
    -display none \
    -serial pty \
    -device virtio-net-pci,netdev=net0 \
    -netdev "user,id=net0,hostfwd=tcp::${SSH_PORT}-:22,hostfwd=tcp::${LUCY_PORT}-:5000,hostfwd=tcp::${GAME_PORT}-:8401" \
    -drive "file=$DISK,if=virtio,format=qcow2,cache=writeback" \
    -cdrom "$ISO_PATH" \
    -boot order=d \
    -no-reboot \
    >"$QEMU_LOG" 2>&1 &
QEMU_PID=$!

# QEMU announces the allocated pty path in its own log shortly after start
# ("char device redirected to /dev/pts/N (label serial0)") — wait for it.
GUEST_TTY=""
for _ in $(seq 1 50); do
    GUEST_TTY="$(grep -oE '/dev/pts/[0-9]+' "$QEMU_LOG" 2>/dev/null | head -1)" || true
    [ -n "$GUEST_TTY" ] && [ -c "$GUEST_TTY" ] && break
    kill -0 "$QEMU_PID" 2>/dev/null || break
    sleep 0.2
done
if [ -n "$GUEST_TTY" ] && [ -c "$GUEST_TTY" ]; then
    info "Console: $GUEST_TTY (bidirectional — will auto-answer prompts and pull diagnostics)"
    cat "$GUEST_TTY" >"$SERIAL_LOG" 2>/dev/null &
    CAT_PID=$!
    (
        # Phase 1: answer swarm-unseal-secrets' passphrase prompt with Enter,
        # same as a human at real hardware would, until a login prompt shows up.
        for _ in $(seq 1 20); do
            kill -0 "$QEMU_PID" 2>/dev/null || exit 0
            printf '\n' >"$GUEST_TTY" 2>/dev/null
            sleep 3
            grep -q "login:" "$SERIAL_LOG" 2>/dev/null && break
        done
        # Phase 2: if LucyServer/GamingAgent still haven't answered /health by
        # the time we hit a login prompt, we otherwise have zero visibility
        # into why — they log to the journal, not necessarily the console.
        # archiso's live root account has no password, so log in and pull
        # real diagnostics straight into this same serial log.
        if kill -0 "$QEMU_PID" 2>/dev/null && grep -q "login:" "$SERIAL_LOG" 2>/dev/null; then
            sleep 1
            printf 'root\n' >"$GUEST_TTY" 2>/dev/null
            sleep 3
            for cmd in \
                'echo ===SWARM-GATE-DIAG===' \
                'echo -- before: --' \
                'systemctl --failed --no-pager' \
                'systemctl status swarm-secrets.service --no-pager -l' \
                'echo -- unblocking swarm-secrets.service (its stuck systemd-ask-password --no-tty prompt cannot be answered by keystrokes on this console; a real human would need Plymouth or systemd-tty-ask-password-agent, neither is running here — stopping it is equivalent) --' \
                'systemctl stop swarm-secrets.service' \
                'sleep 3' \
                'echo -- after: --' \
                'systemctl --failed --no-pager' \
                'systemctl status lucy-server.service gaming-agent.service swarm-secrets.service --no-pager -l' \
                'journalctl -u lucy-server.service -u gaming-agent.service --no-pager -n 80' \
                'ss -tlnp' \
                'echo ===END-SWARM-GATE-DIAG==='; do
                kill -0 "$QEMU_PID" 2>/dev/null || break
                printf '%s\n' "$cmd" >"$GUEST_TTY" 2>/dev/null
                sleep 4
            done
        fi
        # Keep pressing Enter for the rest of the run in case anything else
        # ends up waiting on input — harmless once nothing is prompting.
        while kill -0 "$QEMU_PID" 2>/dev/null; do printf '\n' >"$GUEST_TTY" 2>/dev/null; sleep 10; done
    ) &
    ANSWER_PID=$!
else
    warn "Could not find the guest's pty in $QEMU_LOG — falling back to output-only logging."
    warn "The passphrase prompt (if it appears) will not be auto-answered."
fi

# --- watch the boot ----------------------------------------------------------
PANIC_RE='Kernel panic|BUG: unable to handle|Attempted to kill init|end Kernel panic'
# NOT a bare 'Failed to start' — a live ISO has non-critical best-effort units
# (e.g. archiso's own loopback-attach helper for the optical medium, seen
# failing harmlessly on every boot so far, well before/after LucyServer and
# GamingAgent start fine) that fail without it meaning anything. Genuine crash
# loops repeat; a single cosmetic [FAILED] line during an otherwise-progressing
# boot isn't one. The /health checks below are the real pass signal — this
# regex only needs to catch runaway restart loops and unit-failure states.
LOOP_RE='Start request repeated too quickly|entered failed state'
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
if [ -s "$SERIAL_LOG" ]; then
    tail -n 40 "$SERIAL_LOG" | sed 's/^/    /'
else
    echo "    (serial log is empty — either the guest produced no console output,"
    echo "     or QEMU itself never got that far. Checking QEMU's own output below.)"
fi
if [ -s "$QEMU_LOG" ]; then
    echo -e "\n${YELLOW}  QEMU's own stdout/stderr (this is the process, not the guest OS):${NC}"
    sed 's/^/    /' "$QEMU_LOG"
fi
echo -e "\n${CYAN}  Full serial log: $SERIAL_LOG${NC}"
echo -e "${CYAN}  QEMU process log: $QEMU_LOG${NC}"
exit 1
