#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  SWARM_OS Ubuntu ISO — Workspace Bootstrap                  ║
# ║  Version: 0.4.0 | Date: 2026-10-04                         ║
# ║  Base: Ubuntu 24.04 LTS (Noble) + CachyOS perf layer        ║
# ║  Build tool: live-build                                      ║
# ║  Run: bash setup-swarm-iso-ubuntu.sh                        ║
# ╚══════════════════════════════════════════════════════════════╝
set -euo pipefail

WORKSPACE="${1:-/mnt/Lucy/swarm-iso-ubuntu}"
VERSION="0.4.0"
DATE="2026-10-04"

echo ""
echo "  ███████╗██╗    ██╗ █████╗ ██████╗ ███╗   ███╗"
echo "  ██╔════╝██║    ██║██╔══██╗██╔══██╗████╗ ████║"
echo "  ███████╗██║ █╗ ██║███████║██████╔╝██╔████╔██║"
echo "  ╚════██║██║███╗██║██╔══██║██╔══██╗██║╚██╔╝██║"
echo "  ███████║╚███╔███╔╝██║  ██║██║  ██║██║ ╚═╝ ██║"
echo "  ╚══════╝ ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝"
echo ""
echo "  ISO Bootstrap v${VERSION} | ${DATE}"
echo "  Workspace → ${WORKSPACE}"
echo ""

# ─── Check deps ───────────────────────────────────────────────
for cmd in lb debootstrap; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "[!] Missing: $cmd"
        echo "    Run: sudo apt install live-build debootstrap"
        exit 1
    fi
done
echo "[✓] live-build found: $(lb --version 2>&1 | head -1)"

# ─── Directory scaffold ────────────────────────────────────────
mkdir -p "$WORKSPACE"/{auto,config/{archives,package-lists,hooks/{live,normal},includes.chroot/{etc/{sysctl.d,udev/rules.d,systemd,swarm},usr/{share/{wayland-sessions,grub/themes/swarm},local/{bin,lib/swarm}},home/lucy/{.config/{sway,waybar},Desktop}},preseed},docs,builds}

cd "$WORKSPACE"
echo "[✓] Directory tree created"

# ══════════════════════════════════════════════════════════════
# auto/config — live-build configuration
# ══════════════════════════════════════════════════════════════
cat > auto/config << 'EOF'
#!/bin/sh
# SWARM_OS live-build auto config v0.4.0 2026-10-04
lb config noauto \
    --distribution noble \
    --architectures amd64 \
    --binary-image iso-hybrid \
    --bootloaders grub-efi \
    --debian-installer none \
    --memtest none \
    --iso-application "SWARM_OS" \
    --iso-preparer "i320k3n/broken" \
    --iso-publisher "SWARM_OS Project" \
    --iso-volume "SWARM_OS_$(date +%Y%m%d)" \
    --apt-recommends false \
    --apt-secure false \
    --mirror-bootstrap "http://archive.ubuntu.com/ubuntu/" \
    --mirror-chroot "http://archive.ubuntu.com/ubuntu/" \
    --mirror-binary "http://archive.ubuntu.com/ubuntu/" \
    --mirror-chroot-security "http://security.ubuntu.com/ubuntu/" \
    --security true \
    --updates true \
    --backports true \
    --linux-packages "linux-image-generic-hwe-24.04" \
    --linux-flavours "generic-hwe-24.04" \
    --bootappend-live "boot=live components quiet splash noresume zswap.enabled=0 mitigations=off systemd.show_status=false" \
    --hostname "swarm-os" \
    --username "lucy" \
    "${@}"
EOF
chmod +x auto/config

cat > auto/build << 'EOF'
#!/bin/sh
lb build noauto "${@}"
EOF
chmod +x auto/build

cat > auto/clean << 'EOF'
#!/bin/sh
lb clean noauto "${@}"
EOF
chmod +x auto/clean

echo "[✓] auto/ scripts written"

# ══════════════════════════════════════════════════════════════
# Package lists
# ══════════════════════════════════════════════════════════════
cat > config/package-lists/00-base.list.chroot << 'EOF'
# SWARM_OS Base — v0.4.0 2026-10-04
live-boot
live-config
live-config-systemd
systemd-sysv
dbus
udev
upower
network-manager
wpasupplicant
pciutils
usbutils
lshw
iproute2
iputils-ping
curl
wget
git
vim
nano
htop
btop
fastfetch
zsh
bash-completion
sudo
lsb-release
apt-transport-https
ca-certificates
gnupg
software-properties-common
rsync
unzip
zip
p7zip-full
EOF

cat > config/package-lists/01-performance.list.chroot << 'EOF'
# CachyOS-style Performance Layer — v0.4.0 2026-10-04
zram-tools
irqbalance
cpufrequtils
thermald
tuned
tuned-utils
earlyoom
preload
iotop
numactl
schedtool
EOF

cat > config/package-lists/02-desktop.list.chroot << 'EOF'
# Wayland Desktop Stack — v0.4.0 2026-10-04
sway
swaybg
swayidle
swaylock
waybar
rofi
rofi-wayland
dunst
foot
wl-clipboard
grim
slurp
pipewire
pipewire-alsa
pipewire-pulse
pipewire-jack
wireplumber
pavucontrol
pamixer
brightnessctl
kanshi
wlr-randr
xdg-utils
xdg-desktop-portal-wlr
polkit
gnome-keyring
xwayland
fonts-noto
fonts-noto-color-emoji
fonts-jetbrains-mono
libnotify-bin
light
EOF

cat > config/package-lists/03-gaming.list.chroot << 'EOF'
# Gaming Stack — v0.4.0 2026-10-04
gamemode
gamescope
mangohud
steam
steam-devices
vulkan-tools
mesa-vulkan-drivers
mesa-utils
libvulkan1
libegl1-mesa
libgl1-mesa-dri
va-driver-all
vdpauinfo
wine64
winetricks
libwine
lutris
EOF

cat > config/package-lists/04-ai.list.chroot << 'EOF'
# AI / Lucille Stack — v0.4.0 2026-10-04
python3
python3-pip
python3-venv
python3-flask
python3-requests
python3-websockets
python3-aiohttp
nodejs
npm
ffmpeg
portaudio19-dev
python3-pyaudio
sqlite3
jq
EOF

cat > config/package-lists/05-dev.list.chroot << 'EOF'
# Dev Tools — v0.4.0 2026-10-04
build-essential
make
cmake
pkg-config
gcc
g++
clang
llvm
python3-dev
libssl-dev
libffi-dev
libsqlite3-dev
strace
ltrace
gdb
valgrind
perf
linux-tools-generic
EOF

echo "[✓] Package lists written"

# ══════════════════════════════════════════════════════════════
# Repo lists (archives)
# ══════════════════════════════════════════════════════════════
cat > config/archives/ubuntu-noble.list.chroot << 'EOF'
deb http://archive.ubuntu.com/ubuntu noble main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu noble-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu noble-backports main restricted universe multiverse
deb http://security.ubuntu.com/ubuntu noble-security main restricted universe multiverse
EOF

# Steam
cat > config/archives/steam.list.chroot << 'EOF'
deb [arch=amd64,i386 signed-by=/usr/share/keyrings/steam.gpg] https://repo.steampowered.com/steam/ stable steam
EOF

echo "[✓] Archive lists written"

# ══════════════════════════════════════════════════════════════
# HOOK 0001 — CachyOS Performance Layer
# ══════════════════════════════════════════════════════════════
cat > config/hooks/live/0001-cachyos-perf.hook.chroot << 'HOOKEOF'
#!/bin/bash
# SWARM_OS Hook: CachyOS Performance Layer v0.4.0 2026-10-04
set -e
echo "[SWARM] Applying CachyOS performance layer..."

# ── sysctl ─────────────────────────────────────────────────────
cat > /etc/sysctl.d/99-swarm-cachyos.conf << 'SYSCTL'
# SWARM_OS CachyOS Performance Layer v0.4.0 2026-10-04
kernel.nmi_watchdog = 0
kernel.unprivileged_userns_clone = 1
kernel.printk = 3 3 3 3
kernel.kptr_restrict = 0
kernel.perf_event_paranoid = 1

# VM / Memory (CachyOS defaults)
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.dirty_ratio = 20
vm.dirty_background_ratio = 5
vm.dirty_writeback_centisecs = 1500
vm.page-cluster = 0
vm.max_map_count = 2147483642
vm.overcommit_memory = 1

# Network — BBR + gaming latency
net.core.netdev_max_backlog = 16384
net.core.somaxconn = 8192
net.core.rmem_default = 1048576
net.core.rmem_max = 16777216
net.core.wmem_default = 1048576
net.core.wmem_max = 16777216
net.core.optmem_max = 65536
net.ipv4.tcp_rmem = 4096 1048576 2097152
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_slow_start_after_idle = 0
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_mtu_probing = 1

# Inotify (dev + steam)
fs.inotify.max_user_watches = 524288
fs.inotify.max_user_instances = 1024

# Huge pages (gaming)
vm.nr_hugepages = 0
vm.hugetlb_shm_group = 0
SYSCTL

# ── IO scheduler udev rules ───────────────────────────────────
cat > /etc/udev/rules.d/60-swarm-ioscheduler.rules << 'UDEV'
# SWARM_OS IO Scheduler v0.4.0 — CachyOS-derived
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
ACTION=="add|change", KERNEL=="sd[a-z]|mmcblk[0-9]*", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="mq-deadline"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/rotational}=="1", ATTR{queue/scheduler}="bfq"
ACTION=="add", SUBSYSTEM=="cpu", TEST=="power/energy_perf_bias", ATTR{power/energy_perf_bias}="6"
UDEV

# ── zram-generator ─────────────────────────────────────────────
cat > /etc/systemd/zram-generator.conf << 'ZRAM'
# SWARM_OS zram config v0.4.0
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
ZRAM

# ── tuned gaming profile ───────────────────────────────────────
mkdir -p /etc/tuned/swarm-gaming
cat > /etc/tuned/swarm-gaming/tuned.conf << 'TUNED'
[main]
summary=SWARM_OS Gaming Profile (CachyOS-derived) v0.4.0

[cpu]
governor=performance
energy_perf_bias=performance
min_perf_pct=100

[vm]
transparent_hugepages=madvise

[disk]
readahead=>4096

[scheduler]
sched_latency_ns=1000000
sched_migration_cost_ns=250000
TUNED

# enable services
systemctl enable irqbalance tuned 2>/dev/null || true
tuned-adm profile swarm-gaming 2>/dev/null || true

echo "[SWARM] ✓ CachyOS perf layer done"
HOOKEOF
chmod +x config/hooks/live/0001-cachyos-perf.hook.chroot

# ══════════════════════════════════════════════════════════════
# HOOK 0002 — Networking (Tailscale)
# ══════════════════════════════════════════════════════════════
cat > config/hooks/live/0002-networking.hook.chroot << 'HOOKEOF'
#!/bin/bash
# SWARM_OS Hook: Tailscale networking v0.4.0 2026-10-04
set -e
echo "[SWARM] Installing Tailscale..."

curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg \
    -o /usr/share/keyrings/tailscale-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] \
    https://pkgs.tailscale.com/stable/ubuntu noble main" \
    > /etc/apt/sources.list.d/tailscale.list

apt-get update -qq
apt-get install -y tailscale

systemctl enable tailscaled NetworkManager 2>/dev/null || true

echo "[SWARM] ✓ Tailscale done"
HOOKEOF
chmod +x config/hooks/live/0002-networking.hook.chroot

# ══════════════════════════════════════════════════════════════
# HOOK 0003 — Ollama + Lucille Model Init
# ══════════════════════════════════════════════════════════════
cat > config/hooks/live/0003-ollama.hook.chroot << 'HOOKEOF'
#!/bin/bash
# SWARM_OS Hook: Ollama AI v0.4.0 2026-10-04
set -e
echo "[SWARM] Installing Ollama..."

curl -fsSL https://ollama.com/install.sh | sh

systemctl enable ollama 2>/dev/null || true

mkdir -p /etc/swarm
cat > /etc/swarm/lucille-models.conf << 'MODELS'
# Lucille AI Models — pulled on first boot
# Edit before build to change defaults
llama3.2:3b
qwen2.5-coder:7b
MODELS

# First-boot model puller service
cat > /etc/systemd/system/lucille-model-init.service << 'SVC'
[Unit]
Description=Lucille First-Boot Model Init
After=ollama.service network-online.target
Requires=ollama.service
ConditionPathExists=!/var/swarm/.models-initialized

[Service]
Type=oneshot
User=lucy
ExecStartPre=/bin/mkdir -p /var/swarm
ExecStart=/usr/local/bin/llcy-model-init
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
SVC

cat > /usr/local/bin/llcy-model-init << 'SCRIPT'
#!/bin/bash
# Lucille first-boot model pull v0.4.0 2026-10-04
set -e
MODELS_CONF="/etc/swarm/lucille-models.conf"
LOG="/var/swarm/model-init.log"
mkdir -p /var/swarm

echo "[LLcy] Model init started $(date)" | tee -a "$LOG"

while IFS= read -r model; do
    [[ "$model" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${model// }" ]] && continue
    echo "[LLcy] Pulling: $model" | tee -a "$LOG"
    ollama pull "$model" 2>&1 | tee -a "$LOG" || \
        echo "[LLcy] WARN: failed to pull $model" | tee -a "$LOG"
done < "$MODELS_CONF"

touch /var/swarm/.models-initialized
echo "[LLcy] Model init complete $(date)" | tee -a "$LOG"
SCRIPT
chmod +x /usr/local/bin/llcy-model-init

systemctl enable lucille-model-init 2>/dev/null || true
mkdir -p /var/swarm

echo "[SWARM] ✓ Ollama + Lucille model init done"
HOOKEOF
chmod +x config/hooks/live/0003-ollama.hook.chroot

# ══════════════════════════════════════════════════════════════
# HOOK 0004 — SWARM Session Scripts
# ══════════════════════════════════════════════════════════════
cat > config/hooks/live/0004-swarm-session.hook.chroot << 'HOOKEOF'
#!/bin/bash
# SWARM_OS Hook: Session setup v0.4.0 2026-10-04
set -e
echo "[SWARM] Setting up sessions..."

# ── create lucy user ───────────────────────────────────────────
useradd -m -s /bin/bash -G sudo,video,audio,input,gamemode,render lucy 2>/dev/null || true
echo "lucy:swarm" | chpasswd
echo "root:swarm" | chpasswd
echo "lucy ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/lucy

# ── wayland session desktop entries ───────────────────────────
cat > /usr/share/wayland-sessions/swarm-gamescope.desktop << 'DESK'
[Desktop Entry]
Name=SWARM_OS GameScope
Comment=Lucille Core AI — Gaming Session
Exec=/usr/local/bin/swarm-session
TryExec=gamescope
Type=Application
DesktopNames=SWARM_OS;GameScope
Keywords=game;steam;swarm;lucille
DESK

cat > /usr/share/wayland-sessions/swarm-sway.desktop << 'DESK'
[Desktop Entry]
Name=SWARM_OS Sway
Comment=Lucille Core AI — Desktop/Dev Session
Exec=/usr/local/bin/swarm-sway-session
TryExec=sway
Type=Application
DesktopNames=SWARM_OS;sway
Keywords=sway;code;dev;swarm;lucille
DESK

# ── gamescope launcher ─────────────────────────────────────────
cat > /usr/local/bin/swarm-session << 'SCRIPT'
#!/bin/bash
# SWARM_OS GameScope Session v0.4.0 2026-10-04
export SWARM_SESSION=gamescope
export SWARM_VERSION="0.4.0"
export MANGOHUD=1
export MANGOHUD_CONFIG="fps,frame_timing,gpu_stats,cpu_stats,ram,vram,full"
export DXVK_ASYNC=1
export VKD3D_CONFIG=dxr
export PROTON_ENABLE_NVAPI=1

/usr/local/bin/llcy-start &

exec gamescope \
    -W 1920 -H 1080 \
    --adaptive-sync \
    --expose-wayland \
    --steam \
    -- steam -gamepadui -pipewire-dmabuf
SCRIPT
chmod +x /usr/local/bin/swarm-session

# ── sway fallback ──────────────────────────────────────────────
cat > /usr/local/bin/swarm-sway-session << 'SCRIPT'
#!/bin/bash
# SWARM_OS Sway Session v0.4.0 2026-10-04
export SWARM_SESSION=sway
export SWARM_VERSION="0.4.0"
export XDG_CURRENT_DESKTOP=sway
export XDG_SESSION_TYPE=wayland
export MOZ_ENABLE_WAYLAND=1
export QT_QPA_PLATFORM=wayland
export GDK_BACKEND=wayland
export SDL_VIDEODRIVER=wayland

/usr/local/bin/llcy-start &
exec sway
SCRIPT
chmod +x /usr/local/bin/swarm-sway-session

# ── Lucille stub launcher ──────────────────────────────────────
cat > /usr/local/bin/llcy-start << 'SCRIPT'
#!/bin/bash
# Lucille Core AI Launcher v0.4.0 2026-10-04
LLCY_HOME="${HOME}/.lucille"
LOG="${LLCY_HOME}/lucille.log"
mkdir -p "$LLCY_HOME"

# Wait for Ollama
for i in $(seq 1 15); do
    ollama list &>/dev/null && break
    sleep 1
done

echo "[LLcy] Lucille Core AI v0.4.0 online — SWARM_OS $(date)" >> "$LOG"
echo "[LLcy] Session: ${SWARM_SESSION:-unknown}" >> "$LOG"
echo "[LLcy] Ollama models: $(ollama list 2>/dev/null | wc -l) loaded" >> "$LOG"

# BoltMatrix integration (when running)
# exec python3 /usr/local/lib/swarm/lucille.py
SCRIPT
chmod +x /usr/local/bin/llcy-start

# ── recovery script ────────────────────────────────────────────
cat > /usr/local/bin/swarm-recover << 'SCRIPT'
#!/bin/bash
# SWARM_OS Recovery Script v0.4.0 2026-10-04
echo ""
echo "  ╔═══════════════════════════════╗"
echo "  ║  SWARM_OS Recovery Mode       ║"
echo "  ║  v0.4.0 — 2026-10-04         ║"
echo "  ╚═══════════════════════════════╝"
echo ""
echo "  1) Launch Sway session"
echo "  2) Launch GameScope session"
echo "  3) Drop to bash"
echo "  4) Disk/filesystem check"
echo "  5) Tailscale status"
echo ""
read -rp "  Choice: " choice
case $choice in
    1) exec /usr/local/bin/swarm-sway-session ;;
    2) exec /usr/local/bin/swarm-session ;;
    3) exec bash ;;
    4) lsblk -f; echo ""; df -h; echo ""; dmesg | grep -i "error\|fail" | tail -20 ;;
    5) tailscale status ;;
    *) echo "Unknown option" ; exit 1 ;;
esac
SCRIPT
chmod +x /usr/local/bin/swarm-recover

# ── swarm-info helper ──────────────────────────────────────────
cat > /usr/local/bin/swarm-info << 'SCRIPT'
#!/bin/bash
# SWARM_OS Info v0.4.0 2026-10-04
source /etc/swarm-release 2>/dev/null || true
echo ""
echo "  SWARM_OS $SWARM_VERSION | $SWARM_DATE"
echo "  Base: $SWARM_BASE"
echo "  AI: $SWARM_AI"
echo "  Kernel: $(uname -r)"
echo "  Session: ${SWARM_SESSION:-unset}"
echo "  Ollama: $(ollama list 2>/dev/null | wc -l) models"
echo "  Tailscale: $(tailscale status 2>/dev/null | head -1 || echo 'down')"
echo ""
SCRIPT
chmod +x /usr/local/bin/swarm-info

echo "[SWARM] ✓ Sessions configured"
HOOKEOF
chmod +x config/hooks/live/0004-swarm-session.hook.chroot

# ══════════════════════════════════════════════════════════════
# HOOK 0005 — Sway + Waybar config for lucy
# ══════════════════════════════════════════════════════════════
cat > config/hooks/live/0005-sway-config.hook.chroot << 'HOOKEOF'
#!/bin/bash
# SWARM_OS Hook: Sway + Waybar config v0.4.0 2026-10-04
set -e
echo "[SWARM] Writing sway/waybar configs..."

LUCY="/home/lucy"
mkdir -p "$LUCY/.config/sway" "$LUCY/.config/waybar"

# ── sway config ────────────────────────────────────────────────
cat > "$LUCY/.config/sway/config" << 'SWAY'
# SWARM_OS Sway Config v0.4.0 2026-10-04
set $mod Mod4
set $term foot
set $menu rofi -show drun
set $accent #00ff88
set $bg     #0a0a0f
set $fg     #c0c0e0
set $warn   #ff4444

output * bg $bg solid_color
default_border pixel 2
default_floating_border pixel 2
client.focused          $accent $bg $fg $accent $accent
client.unfocused        #333355 $bg #666688 #333355
client.focused_inactive #333355 $bg #888899 #333355
gaps inner 8
gaps outer 4
smart_gaps on
smart_borders on

bindsym $mod+Return      exec $term
bindsym $mod+d           exec $menu
bindsym $mod+q           kill
bindsym $mod+f           fullscreen
bindsym $mod+h           splith
bindsym $mod+v           splitv
bindsym $mod+Shift+space floating toggle
bindsym $mod+space       focus mode_toggle
bindsym $mod+Shift+e     exec swaynag -t warning -m 'Exit SWARM_OS?' -b 'Yes' 'swaymsg exit'
bindsym $mod+Shift+c     reload

bindsym $mod+Left        focus left
bindsym $mod+Right       focus right
bindsym $mod+Up          focus up
bindsym $mod+Down        focus down
bindsym $mod+Shift+Left  move left
bindsym $mod+Shift+Right move right
bindsym $mod+Shift+Up    move up
bindsym $mod+Shift+Down  move down

bindsym $mod+1 workspace number 1
bindsym $mod+2 workspace number 2
bindsym $mod+3 workspace number 3
bindsym $mod+4 workspace number 4
bindsym $mod+5 workspace number 5
bindsym $mod+Shift+1 move container to workspace number 1
bindsym $mod+Shift+2 move container to workspace number 2
bindsym $mod+Shift+3 move container to workspace number 3
bindsym $mod+Shift+4 move container to workspace number 4
bindsym $mod+Shift+5 move container to workspace number 5

# Resize mode
mode "resize" {
    bindsym Left  resize shrink width  20px
    bindsym Right resize grow   width  20px
    bindsym Up    resize shrink height 20px
    bindsym Down  resize grow   height 20px
    bindsym Return mode "default"
    bindsym Escape mode "default"
}
bindsym $mod+r mode "resize"

# Media
bindsym XF86AudioRaiseVolume exec pamixer -i 5 && notify-send "Volume" "$(pamixer --get-volume)%"
bindsym XF86AudioLowerVolume exec pamixer -d 5 && notify-send "Volume" "$(pamixer --get-volume)%"
bindsym XF86AudioMute        exec pamixer -t
bindsym XF86MonBrightnessUp  exec brightnessctl s +10%
bindsym XF86MonBrightnessDown exec brightnessctl s 10%-
bindsym Print                exec grim -g "$(slurp)" ~/Desktop/screenshot-$(date +%Y%m%d-%H%M%S).png

# Gaming workspace
bindsym $mod+g exec /usr/local/bin/swarm-session

# Input
input "type:keyboard" { xkb_layout us; xkb_options caps:escape }
input "type:touchpad" {
    tap enabled
    natural_scroll enabled
    dwt enabled
}

# Autostart
exec waybar
exec dunst
exec /usr/local/bin/llcy-start
exec nm-applet --indicator

bar {
    swaybar_command waybar
}
SWAY

# ── waybar config ──────────────────────────────────────────────
cat > "$LUCY/.config/waybar/config.jsonc" << 'WAYBAR'
// SWARM_OS Waybar v0.4.0 2026-10-04
{
    "layer": "top",
    "position": "top",
    "height": 30,
    "spacing": 4,
    "modules-left":   ["sway/workspaces", "sway/mode", "sway/scratchpad"],
    "modules-center": ["clock"],
    "modules-right":  ["cpu", "memory", "temperature", "battery",
                       "network", "pulseaudio", "tray"],

    "sway/workspaces": {
        "disable-scroll": true,
        "format": "{name}"
    },
    "sway/mode":       { "format": "<span style='italic'>{}</span>" },
    "sway/scratchpad": {
        "format": "{icon} {count}",
        "show-empty": false,
        "format-icons": ["", ""]
    },
    "clock": {
        "format":         "{:%Y-%m-%d  %H:%M}",
        "format-alt":     "{:%A, %B %d}",
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt>{calendar}</tt>"
    },
    "cpu": {
        "format": " {usage}%",
        "tooltip": true,
        "interval": 2
    },
    "memory": {
        "format": " {used:0.1f}G",
        "interval": 5
    },
    "temperature": {
        "critical-threshold": 80,
        "format": "{icon} {temperatureC}°C",
        "format-icons": ["", "", ""]
    },
    "battery": {
        "states": { "warning": 30, "critical": 15 },
        "format":          "{icon} {capacity}%",
        "format-charging": " {capacity}%",
        "format-plugged":  " {capacity}%",
        "format-icons":    ["", "", "", "", ""]
    },
    "network": {
        "format-wifi":       " {essid} ({signalStrength}%)",
        "format-ethernet":   " {ifname}",
        "format-disconnected": "⚠ Disconnected",
        "tooltip-format":    "{ifname}: {ipaddr}/{cidr}"
    },
    "pulseaudio": {
        "format":        "{icon} {volume}%",
        "format-muted":  " muted",
        "format-icons":  { "default": ["", "", " "] },
        "on-click":      "pavucontrol"
    },
    "tray": { "spacing": 8, "icon-size": 16 }
}
WAYBAR

cat > "$LUCY/.config/waybar/style.css" << 'CSS'
/* SWARM_OS Waybar Style v0.4.0 2026-10-04 */
* {
    font-family: "JetBrains Mono", "Noto Sans", monospace;
    font-size: 12px;
    min-height: 0;
}
window#waybar {
    background-color: rgba(10, 10, 15, 0.96);
    color: #c0c0e0;
    border-bottom: 1px solid #00ff88;
    transition-duration: 0.3s;
}
#workspaces button {
    padding: 0 8px;
    color: #555577;
    border-bottom: 2px solid transparent;
    transition: all 0.2s;
}
#workspaces button:hover    { color: #c0c0e0; background: rgba(0,255,136,0.1); }
#workspaces button.focused  { color: #00ff88; border-bottom: 2px solid #00ff88; }
#workspaces button.urgent   { color: #ff4444; border-bottom: 2px solid #ff4444; }
#clock       { color: #00ff88; padding: 0 12px; }
#cpu         { color: #ff8800; }
#memory      { color: #8888ff; }
#temperature { color: #ffdd00; }
#temperature.critical { color: #ff4444; animation: blink 0.5s infinite; }
#battery     { color: #00ff88; }
#battery.warning  { color: #ffaa00; }
#battery.critical { color: #ff4444; animation: blink 0.5s infinite; }
#network     { color: #00ccff; }
#network.disconnected { color: #ff4444; }
#pulseaudio  { color: #cc88ff; }
#tray        { padding: 0 4px; }
@keyframes blink { to { background-color: rgba(255,68,68,0.2); } }
CSS

# ── bashrc for lucy ────────────────────────────────────────────
cat > "$LUCY/.bashrc" << 'BASHRC'
# SWARM_OS .bashrc v0.4.0 2026-10-04
source /etc/swarm-release 2>/dev/null

# Prompt
export PS1='\[\e[32m\][LLcy@\h \W]\[\e[0m\]\$ '
export EDITOR=vim
export VISUAL=vim
export TERM=xterm-256color

# SWARM aliases
alias swarm-info='/usr/local/bin/swarm-info'
alias swarm-recover='/usr/local/bin/swarm-recover'
alias llcy-start='/usr/local/bin/llcy-start'
alias models='ollama list'
alias fetch='fastfetch'
alias ll='ls -lah --color=auto'
alias ts='tailscale status'

# Env
export MANGOHUD=1
export DXVK_ASYNC=1
export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d

# Greeting
fastfetch 2>/dev/null || true
BASHRC

chown -R lucy:lucy "$LUCY"
echo "[SWARM] ✓ Sway + Waybar done"
HOOKEOF
chmod +x config/hooks/live/0005-sway-config.hook.chroot

# ══════════════════════════════════════════════════════════════
# HOOK 0006 — Branding + MOTD
# ══════════════════════════════════════════════════════════════
cat > config/hooks/live/0006-branding.hook.chroot << 'HOOKEOF'
#!/bin/bash
# SWARM_OS Hook: Branding v0.4.0 2026-10-04
set -e
echo "[SWARM] Applying branding..."

# ── /etc/swarm-release ────────────────────────────────────────
cat > /etc/swarm-release << 'REL'
SWARM_OS="SWARM_OS"
SWARM_VERSION="0.4.0"
SWARM_DATE="2026-10-04"
SWARM_BASE="Ubuntu 24.04 LTS (Noble Numbat)"
SWARM_KERNEL="linux-generic-hwe-24.04"
SWARM_PERF="CachyOS Performance Layer"
SWARM_AI="Lucille Core AI (LLcy) v0.4"
SWARM_BUILDER="i320k3n/broken"
SWARM_SESSION_DEFAULT="gamescope"
REL

# ── os-release override ────────────────────────────────────────
cat > /etc/os-release << 'OSREL'
NAME="SWARM_OS"
VERSION="0.4.0"
ID=swarm
ID_LIKE=ubuntu
PRETTY_NAME="SWARM_OS 0.4.0 (Noble + CachyOS)"
HOME_URL="https://github.com/i320k3n/swarm-os"
SUPPORT_URL="https://github.com/i320k3n/swarm-os"
BUG_REPORT_URL="https://github.com/i320k3n/swarm-os/issues"
OSREL

# ── MOTD ──────────────────────────────────────────────────────
cat > /etc/motd << 'MOTD'

  ███████╗██╗    ██╗ █████╗ ██████╗ ███╗   ███╗    ██████╗ ███████╗
  ██╔════╝██║    ██║██╔══██╗██╔══██╗████╗ ████║   ██╔═══██╗██╔════╝
  ███████╗██║ █╗ ██║███████║██████╔╝██╔████╔██║   ██║   ██║███████╗
  ╚════██║██║███╗██║██╔══██║██╔══██╗██║╚██╔╝██║   ██║   ██║╚════██║
  ███████║╚███╔███╔╝██║  ██║██║  ██║██║ ╚═╝ ██║   ╚██████╔╝███████║
  ╚══════╝ ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝    ╚═════╝ ╚══════╝

  v0.4.0 | Ubuntu 24.04 LTS + CachyOS | Lucille Core AI | 2026-10-04
  ─────────────────────────────────────────────────────────────────────
  live user: lucy  |  pass: swarm  |  sudo: NOPASSWD
  run `swarm-info` for system status
  run `swarm-recover` for recovery options

MOTD

echo "[SWARM] ✓ Branding done"
HOOKEOF
chmod +x config/hooks/live/0006-branding.hook.chroot

# ══════════════════════════════════════════════════════════════
# HOOK 0007 — Steam key import
# ══════════════════════════════════════════════════════════════
cat > config/hooks/live/0007-steam-key.hook.chroot << 'HOOKEOF'
#!/bin/bash
# SWARM_OS Hook: Steam GPG key v0.4.0 2026-10-04
set -e
echo "[SWARM] Importing Steam GPG key..."

dpkg --add-architecture i386
curl -fsSL https://repo.steampowered.com/steam/archive/precise/steam.gpg \
    -o /usr/share/keyrings/steam.gpg 2>/dev/null || \
    curl -fsSL https://store.steampowered.com/about/ -o /dev/null

apt-get update -qq || true
echo "[SWARM] ✓ Steam key done"
HOOKEOF
chmod +x config/hooks/live/0007-steam-key.hook.chroot

# ══════════════════════════════════════════════════════════════
# GRUB theme stub
# ══════════════════════════════════════════════════════════════
cat > config/hooks/live/0008-grub-theme.hook.chroot << 'HOOKEOF'
#!/bin/bash
# SWARM_OS Hook: GRUB theme v0.4.0 2026-10-04
set -e
echo "[SWARM] Setting GRUB theme..."

THEME="/boot/grub/themes/swarm"
mkdir -p "$THEME"

cat > "$THEME/theme.txt" << 'GRUB'
# SWARM_OS GRUB Theme v0.4.0 2026-10-04
desktop-color: "#0a0a0f"
title-text: ""
message-font: "JetBrains Mono Regular 12"
message-color: "#00ff88"
terminal-font: "JetBrains Mono Regular 11"

+ label {
    top = 5%
    left = 0
    width = 100%
    align = "center"
    text = "SWARM_OS v0.4 — Lucille Core AI"
    font = "JetBrains Mono Regular 18"
    color = "#00ff88"
}

+ boot_menu {
    left = 15%
    top = 15%
    width = 70%
    height = 65%
    item_font = "JetBrains Mono Regular 13"
    item_color = "#c0c0e0"
    selected_item_color = "#00ff88"
    icon_width = 24
    icon_height = 24
    item_height = 42
    item_padding = 12
    item_icon_space = 12
    scrollbar = true
    scrollbar_thumb = "scrollbar_thumb.png"
}

+ label {
    top = 90%
    left = 0
    width = 100%
    align = "center"
    text = "Ubuntu 24.04 + CachyOS — i320k3n/broken"
    font = "JetBrains Mono Regular 9"
    color = "#333366"
}
GRUB

sed -i 's|^#GRUB_THEME=.*|GRUB_THEME="/boot/grub/themes/swarm/theme.txt"|' \
    /etc/default/grub || \
    echo 'GRUB_THEME="/boot/grub/themes/swarm/theme.txt"' >> /etc/default/grub

update-grub 2>/dev/null || true
echo "[SWARM] ✓ GRUB theme done"
HOOKEOF
chmod +x config/hooks/live/0008-grub-theme.hook.chroot

# ══════════════════════════════════════════════════════════════
# Preseed for live configuration
# ══════════════════════════════════════════════════════════════
cat > config/preseed/swarm.cfg.chroot << 'EOF'
# SWARM_OS preseed v0.4.0 2026-10-04
d-i live-config/user-default-groups string audio cdrom dialout floppy video plugdev netdev powerdev scanner bluetooth gamemode render
d-i live-config/hostname string swarm-os
d-i live-config/user-fullname string "Lucille SWARM"
d-i live-config/username string lucy
d-i live-config/user-password-crypted string $6$swarm$randomhash
EOF

# ══════════════════════════════════════════════════════════════
# Main build.sh
# ══════════════════════════════════════════════════════════════
cat > build.sh << 'BUILDSH'
#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║  SWARM_OS Ubuntu ISO Builder v0.4.0                        ║
# ║  Date: 2026-10-04                                           ║
# ║  Run: sudo bash build.sh                                    ║
# ╚══════════════════════════════════════════════════════════════╝
set -euo pipefail

VERSION="0.4.0"
BUILD_DATE="$(date +%Y%m%d-%H%M)"
WORKSPACE="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="/mnt/Lucy/builds"
ISO_NAME="swarm-os-ubuntu-v${VERSION}-${BUILD_DATE}.iso"
LOG_FILE="${OUTPUT_DIR}/build-${BUILD_DATE}.log"

cd "$WORKSPACE"
mkdir -p "$OUTPUT_DIR"

print_banner() {
cat << 'BANNER'

  ███████╗██╗    ██╗ █████╗ ██████╗ ███╗   ███╗    ██████╗ ███████╗
  ██╔════╝██║    ██║██╔══██╗██╔══██╗████╗ ████║   ██╔═══██╗██╔════╝
  ███████╗██║ █╗ ██║███████║██████╔╝██╔████╔██║   ██║   ██║███████╗
  ╚════██║██║███╗██║██╔══██║██╔══██╗██║╚██╔╝██║   ██║   ██║╚════██║
  ███████║╚███╔███╔╝██║  ██║██║  ██║██║ ╚═╝ ██║   ╚██████╔╝███████║
  ╚══════╝ ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝    ╚═════╝ ╚══════╝

BANNER
echo "  ISO Builder v${VERSION} | $(date)"
echo "  Output → ${OUTPUT_DIR}/${ISO_NAME}"
echo ""
}

check_deps() {
    echo "[*] Checking dependencies..."
    local missing=()
    for cmd in lb debootstrap curl; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    if [ ${#missing[@]} -gt 0 ]; then
        echo "[-] Missing: ${missing[*]}"
        echo "    Fix: sudo apt install live-build debootstrap curl"
        exit 1
    fi
    echo "[✓] Dependencies OK"
    echo "[✓] live-build: $(lb --version 2>&1 | head -1)"
}

clean_build() {
    echo "[*] Cleaning previous build artifacts..."
    sudo lb clean --purge 2>/dev/null || true
    rm -f live-image-amd64.hybrid.iso 2>/dev/null || true
    echo "[✓] Clean done"
}

configure() {
    echo "[*] Configuring live-build..."
    sudo bash auto/config
    echo "[✓] Config done"
}

build_iso() {
    echo "[*] Building ISO — this takes 20-40 min depending on internet speed..."
    echo "[*] Log: $LOG_FILE"
    sudo lb build 2>&1 | tee "$LOG_FILE"
}

finalize() {
    if [ -f "live-image-amd64.hybrid.iso" ]; then
        mv live-image-amd64.hybrid.iso "${OUTPUT_DIR}/${ISO_NAME}"
        local size sha
        size=$(du -sh "${OUTPUT_DIR}/${ISO_NAME}" | cut -f1)
        sha=$(sha256sum "${OUTPUT_DIR}/${ISO_NAME}" | cut -d' ' -f1)
        echo ""
        echo "╔══════════════════════════════════════════════════════╗"
        echo "║  ✅ BUILD COMPLETE                                   ║"
        echo "╠══════════════════════════════════════════════════════╣"
        echo "║  ISO:    ${OUTPUT_DIR}/${ISO_NAME}"
        echo "║  Size:   ${size}"
        echo "║  SHA256: ${sha:0:32}..."
        echo "║  Log:    ${LOG_FILE}"
        echo "╚══════════════════════════════════════════════════════╝"
        echo ""
        echo "Next: copy to Ventoy USB"
        echo "  cp ${OUTPUT_DIR}/${ISO_NAME} /path/to/ventoy/usb/"
    else
        echo ""
        echo "╔══════════════════════════════╗"
        echo "║  ❌ BUILD FAILED              ║"
        echo "╚══════════════════════════════╝"
        echo "  Check log: $LOG_FILE"
        exit 1
    fi
}

# ── main ──────────────────────────────────────────────────────
print_banner
check_deps

case "${1:-full}" in
    clean)    clean_build ;;
    config)   configure ;;
    build)    build_iso ; finalize ;;
    full)     clean_build ; configure ; build_iso ; finalize ;;
    *)        echo "Usage: $0 [full|clean|config|build]" ; exit 1 ;;
esac
BUILDSH
chmod +x build.sh

# ══════════════════════════════════════════════════════════════
# docs/build-notes.md
# ══════════════════════════════════════════════════════════════
cat > docs/build-notes.md << 'DOC'
# SWARM_OS Ubuntu ISO — Build Notes
Version: 0.4.0 | Date: 2026-10-04

## First-time setup (Ubuntu host)

```bash
# Install live-build
sudo apt update
sudo apt install live-build debootstrap curl

# Verify mounts
lsblk -f | grep -E "62f0e009|419daf1b"

# Bootstrap workspace (already done if you have this file)
cd /mnt/Lucy
bash setup-swarm-iso-ubuntu.sh

# Build ISO
cd /mnt/Lucy/swarm-iso-ubuntu
sudo bash build.sh
```

## What the build includes

| Layer | Contents |
|---|---|
| Base | Ubuntu 24.04 LTS (Noble Numbat) |
| Kernel | linux-generic-hwe-24.04 |
| Performance | CachyOS sysctl, IO scheduler, zram-zstd, tuned gaming profile |
| Desktop | Gamescope (primary) → Sway (fallback), Waybar |
| Gaming | Steam, Gamemode, MangoHud, Vulkan, Wine, Lutris |
| AI | Ollama + Lucille Core AI stub + first-boot model pull |
| Network | Tailscale, NetworkManager |
| Dev | Python3, Node, GCC, Clang |
| Live user | `lucy` / pass: `swarm` |

## CachyOS perf tweaks ported to Ubuntu

- `vm.swappiness=10`, BBR TCP, max_map_count=2147483642
- BORE scheduler pending (requires kernel build — Phase 2)
- IO scheduler: none/NVMe, mq-deadline/SSD, bfq/HDD
- zram-zstd at 50% RAM, swap priority 100
- tuned `swarm-gaming` profile (performance governor)

## Phase 2 — BORE kernel

```bash
# When ready, build linux-cachyos-bore .deb:
git clone https://github.com/CachyOS/linux-cachyos.git
cd linux-cachyos
# adapt PKGBUILD → debian/rules (requires packaging knowledge)
# or use ubuntu-mainline + custom config with CONFIG_SCHED_BORE=y
```

## Build outputs

```
/mnt/Lucy/builds/
├── swarm-os-ubuntu-v0.4.0-YYYYMMDD-HHMM.iso
└── build-YYYYMMDD-HHMM.log
```

## Ventoy deployment

```bash
# List Ventoy USB
lsblk | grep -v loop

# Copy ISO (no extraction needed — Ventoy boots it directly)
cp /mnt/Lucy/builds/swarm-os-ubuntu-v0.4.0-*.iso /media/$USER/ventoy/
```
DOC

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  ✅ SWARM_OS Ubuntu ISO workspace ready                 ║"
echo "╠══════════════════════════════════════════════════════════╣"
echo "║  Location: ${WORKSPACE}"
echo "║"
echo "║  To build:                                               ║"
echo "║    cd ${WORKSPACE}"
echo "║    sudo bash build.sh                                    ║"
echo "║"
echo "║  Or step by step:                                        ║"
echo "║    sudo bash build.sh clean                              ║"
echo "║    sudo bash build.sh config                             ║"
echo "║    sudo bash build.sh build                              ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
