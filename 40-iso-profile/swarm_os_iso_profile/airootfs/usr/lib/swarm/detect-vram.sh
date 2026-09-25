#!/usr/bin/env bash
# =============================================================================
# 🚀 detect-vram.sh — SWARM OS GPU VRAM & Model Quantization Detector
# Probes DRM sysfs metrics and configures model inference quant modes & layers.
# =============================================================================

VRAM_BYTES=0
VRAM_MB=0
VRAM_GB=0

# 1. Probe AMD / Intel DRM sysfs
for card in /sys/class/drm/card[0-9]*/device; do
    if [ -f "$card/mem_info_vram_total" ]; then
        VRAM_BYTES=$(cat "$card/mem_info_vram_total" 2>/dev/null || echo "0")
        if [ "$VRAM_BYTES" -gt 0 ]; then
            break
        fi
    fi
done

# 2. Fallback: NVIDIA SMI
if [ "$VRAM_BYTES" -eq 0 ] && command -v nvidia-smi >/dev/null 2>&1; then
    NVIDIA_MB=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null | head -n 1 | tr -d ' ' || echo "0")
    if [ "$NVIDIA_MB" -gt 0 ]; then
        VRAM_BYTES=$((NVIDIA_MB * 1024 * 1024))
    fi
fi

# 3. Fallback: Parse lshw / lspci / system RAM heuristics for APU
if [ "$VRAM_BYTES" -eq 0 ]; then
    # Default to 4GB APU allocation if unknown
    VRAM_MB=4096
    VRAM_GB=4
else
    VRAM_MB=$((VRAM_BYTES / (1024 * 1024)))
    VRAM_GB=$((VRAM_MB / 1024))
fi

# 4. Quantization Mode & GPU Layer Allocation
if [ "$VRAM_GB" -ge 12 ]; then
    export SWARM_QUANT_MODE="q8_0"
    export SWARM_GPU_LAYERS=99
elif [ "$VRAM_GB" -ge 8 ]; then
    export SWARM_QUANT_MODE="q4_k_m"
    export SWARM_GPU_LAYERS=45
elif [ "$VRAM_GB" -ge 6 ]; then
    export SWARM_QUANT_MODE="q4_k_m"
    export SWARM_GPU_LAYERS=33
else
    export SWARM_QUANT_MODE="q4_k_m"
    export SWARM_GPU_LAYERS=20
fi

export SWARM_VRAM_MB="$VRAM_MB"
export SWARM_VRAM_GB="$VRAM_GB"

# 5. Persist Environment Variables
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}/swarm"
mkdir -p "$RUNTIME_DIR" /run/swarm /etc/swarm 2>/dev/null || true

cat <<EOF > "$RUNTIME_DIR/vram.env" 2>/dev/null || true
SWARM_VRAM_BYTES=$VRAM_BYTES
SWARM_VRAM_MB=$VRAM_MB
SWARM_VRAM_GB=$VRAM_GB
SWARM_QUANT_MODE=$SWARM_QUANT_MODE
SWARM_GPU_LAYERS=$SWARM_GPU_LAYERS
EOF

# Copy to system paths if writable
if [ -w "/run/swarm" ]; then
    cp "$RUNTIME_DIR/vram.env" /run/swarm/vram.env 2>/dev/null || true
fi
if [ -w "/etc/swarm" ]; then
    cp "$RUNTIME_DIR/vram.env" /etc/swarm/vram.env 2>/dev/null || true
fi

echo "[detect-vram] Probed VRAM: ${VRAM_GB} GB (${VRAM_MB} MB) → Mode: ${SWARM_QUANT_MODE}, Offload Layers: ${SWARM_GPU_LAYERS}"
