#!/usr/bin/env bash
# ==============================================================================
# SWARM_OS & LUCILLE AI - QEMU KVM HIGH-PERFORMANCE VM LAUNCHER
# Native 1440p / Hardware Accelerated KVM Virtual Machine
# ==============================================================================

set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LATEST_FOUND_ISO=$(ls -t "$DIR"/swarm-os-*.iso "$DIR"/swarm_os-*.iso 2>/dev/null | head -n 1)
ISO_PATH="${1:-${LATEST_FOUND_ISO:-$DIR/swarm_os-2026.08.30-x86_64.iso}}"
DISK_PATH="$DIR/swarm_vm_disk.qcow2"
DISK_SIZE="32G"
MEM_SIZE="8192"
CPUS="$(nproc 2>/dev/null || echo 4)"

echo -e "\033[1;32m⚡ [SWARM_OS] Initializing High-Performance KVM Virtual Machine...\033[0m"
echo -e "\033[1;36m• ISO Target:\033[0m $ISO_PATH"
echo -e "\033[1;36m• Virtual Disk:\033[0m $DISK_PATH ($DISK_SIZE)"
echo -e "\033[1;36m• Allocated RAM:\033[0m ${MEM_SIZE}MB | \033[1;36mCPUs:\033[0m $CPUS cores"

if [ ! -f "$ISO_PATH" ]; then
    echo -e "\033[1;31m[ERROR] ISO not found at: $ISO_PATH\033[0m"
    echo "Usage: $0 [/path/to/custom_swarm_os.iso]"
    exit 1
fi

# Create sparse virtual disk if it doesn't already exist
if [ ! -f "$DISK_PATH" ]; then
    echo -e "\033[1;33m• Creating sparse QCOW2 virtual drive: $DISK_PATH ($DISK_SIZE)...\033[0m"
    qemu-img create -f qcow2 "$DISK_PATH" "$DISK_SIZE"
fi

# Detect KVM hardware acceleration
KVM_FLAGS=""
if [ -w /dev/kvm ]; then
    echo -e "\033[1;32m• KVM Hardware Acceleration: ACTIVE (/dev/kvm)\033[0m"
    KVM_FLAGS="-enable-kvm -cpu host"
else
    echo -e "\033[1;33m• KVM device not writable, falling back to TCG emulation (cpu max)...\033[0m"
    KVM_FLAGS="-cpu max"
fi

# Detect UEFI OVMF Firmware
UEFI_FLAGS=""
OVMF_CODE="/usr/share/edk2-ovmf/x64/OVMF_CODE.4m.fd"
OVMF_VARS_SRC="/usr/share/edk2-ovmf/x64/OVMF_VARS.4m.fd"
LOCAL_VARS="$DIR/swarm_ovmf_vars.fd"

if [ -f "$OVMF_CODE" ] && [ -f "$OVMF_VARS_SRC" ]; then
    if [ ! -f "$LOCAL_VARS" ]; then
        cp "$OVMF_VARS_SRC" "$LOCAL_VARS"
    fi
    echo -e "\033[1;32m• UEFI (OVMF) Firmware: ENABLED\033[0m"
    UEFI_FLAGS="-drive if=pflash,format=raw,readonly=on,file=$OVMF_CODE -drive if=pflash,format=raw,file=$LOCAL_VARS"
fi

# Audio Device Setup
AUDIO_FLAGS=""
if [ -S "/run/user/$UID/pulse/native" ]; then
    AUDIO_FLAGS="-audiodev pa,id=snd0,server=/run/user/$UID/pulse/native -device ich9-intel-hda -device hda-output,audiodev=snd0"
else
    AUDIO_FLAGS="-audiodev alsa,id=snd0 -device ich9-intel-hda -device hda-output,audiodev=snd0"
fi

# Launch QEMU
echo -e "\033[1;35m🚀 Launching SWARM_OS in QEMU GTK Window (Resolution auto-adapting to 1440p)...\033[0m"
echo -e "\033[1;37m• Port Forwarding: SSH -> localhost:2222 | HTTP -> localhost:8080\033[0m"
echo -e "\033[1;37m• Press Ctrl+Alt+G to release mouse/keyboard from VM window.\033[0m"

exec qemu-system-x86_64 \
    $KVM_FLAGS \
    -m "$MEM_SIZE" \
    -smp "$CPUS" \
    $UEFI_FLAGS \
    -vga virtio \
    -display gtk,gl=off,show-menubar=on \
    -device virtio-net-pci,netdev=net0 \
    -netdev user,id=net0,hostfwd=tcp::2222-:22,hostfwd=tcp::8080-:80 \
    -drive file="$DISK_PATH",if=virtio,format=qcow2,cache=writeback \
    -cdrom "$ISO_PATH" \
    -boot order=d,menu=on \
    $AUDIO_FLAGS
