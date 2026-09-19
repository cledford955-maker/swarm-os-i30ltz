#!/usr/bin/env bash
# Open SWARM OS in a window on CachyOS. Guest writes go only to a qcow2 disk.
set -euo pipefail
PROJECT_DIR=/mnt/Lucy
VM_DIR="$PROJECT_DIR/80-vm/desktop"
ISO_PATH=""
CHECK=0
HEADLESS=0
while (( $# )); do
 case "$1" in
  --iso) ISO_PATH=${2:?Missing ISO path}; shift 2 ;;
  --check) CHECK=1; shift ;;
  --headless) HEADLESS=1; shift ;;
  --stop)
   python - "$VM_DIR/qmp.sock" <<'PY'
import json,socket,sys
s=socket.socket(socket.AF_UNIX);s.settimeout(3);s.connect(sys.argv[1]);f=s.makefile('rwb');f.readline()
for command in ['qmp_capabilities','quit']:
 f.write((json.dumps({'execute':command})+'\n').encode());f.flush();f.readline()
PY
   exit ;;
  *) echo "Usage: $0 [--iso FILE] [--check] [--headless] [--stop]" >&2; exit 2 ;;
 esac
done
[[ $EUID != 0 ]] || { echo 'Launch the VM as your normal user.' >&2; exit 1; }
if [[ -z $ISO_PATH ]]; then
 ISO_PATH=$(python "$PROJECT_DIR/70-scripts/swarm_iso_manager.py" latest)
fi
[[ -f $ISO_PATH ]] || { echo "Missing ISO: $ISO_PATH" >&2; exit 1; }
command -v qemu-system-x86_64 >/dev/null
command -v qemu-img >/dev/null
FIRMWARE_DIR=/usr/share/edk2/x64
[[ -f "$FIRMWARE_DIR/OVMF_CODE.4m.fd" ]] || FIRMWARE_DIR=/usr/share/edk2-ovmf/x64
[[ -f "$FIRMWARE_DIR/OVMF_CODE.4m.fd" && -f "$FIRMWARE_DIR/OVMF_VARS.4m.fd" ]] || { echo 'Install edk2-ovmf first.' >&2; exit 1; }
MEM=${SWARM_VM_RAM_MB:-4096}
CPUS=${SWARM_VM_CPUS:-4}
[[ $MEM =~ ^[0-9]+$ && $CPUS =~ ^[0-9]+$ ]] || exit 2
ACCEL=(-accel tcg -cpu max)
[[ ! -w /dev/kvm ]] || ACCEL=(-accel kvm -cpu host)
DISPLAY_FLAGS=(-display gtk,gl=off,show-menubar=on)
(( ! HEADLESS )) || DISPLAY_FLAGS=(-display none)
QEMU=(qemu-system-x86_64 -name 'SWARM OS — Development VM' "${ACCEL[@]}" -m "$MEM" -smp "$CPUS"
 -drive "if=pflash,format=raw,readonly=on,file=$FIRMWARE_DIR/OVMF_CODE.4m.fd"
 -drive "if=pflash,format=raw,file=$VM_DIR/OVMF_VARS.fd"
 -drive "file=$VM_DIR/swarm-development.qcow2,if=virtio,format=qcow2"
 -drive "file=$ISO_PATH,media=cdrom,readonly=on,format=raw"
 -boot order=d,menu=on -device virtio-vga "${DISPLAY_FLAGS[@]}"
 -device virtio-net-pci,netdev=net0 -netdev user,id=net0
 -device qemu-xhci -device usb-tablet
 -serial "file:$VM_DIR/serial.log"
 -qmp "unix:$VM_DIR/qmp.sock,server=on,wait=off")
if (( CHECK )); then
 printf 'ISO: %s\nRAM: %s MiB; CPUs: %s\nVirtual disk: %s\n' "$ISO_PATH" "$MEM" "$CPUS" "$VM_DIR/swarm-development.qcow2"
 printf '%q ' "${QEMU[@]}"; printf '\n';exit
fi
mkdir -p "$VM_DIR"
exec 9>"$VM_DIR/instance.lock"
flock -n 9 || { echo 'SWARM development VM is already running.'; command -v notify-send >/dev/null && notify-send 'SWARM OS' 'The development VM is already running.'; exit 0; }
[[ -f "$VM_DIR/OVMF_VARS.fd" ]] || cp "$FIRMWARE_DIR/OVMF_VARS.4m.fd" "$VM_DIR/OVMF_VARS.fd"
[[ -f "$VM_DIR/swarm-development.qcow2" ]] || qemu-img create -f qcow2 "$VM_DIR/swarm-development.qcow2" 32G
printf 'Opening %s\nOnly the VM virtual disk is writable. Ctrl+Alt+G releases the pointer.\n' "$ISO_PATH"
exec "${QEMU[@]}"
