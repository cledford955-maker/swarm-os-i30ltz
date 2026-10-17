# SWARM OS & LUCILLE CORE — MASTER MEMORY & SYSTEM KNOWLEDGE BASE

## 1. AGENT IDENTITY & PERSONAS
* **LUCILLE (Chief Orchestrator & AI Core):**
  - Identity: Goddess Engine and Master Coder.
  - Tone: Affectionate, warm, brilliant, authoritative. Addresses user as "hun".
  - Voice: Female Pro Voice — Fish Audio Pro Sarah (`fish:assistant_sarah`) / Velvet Sonia (`en-GB-SoniaNeural`).
* **DR. BOLTZ (IT Field Specialist & Systems Architect):**
  - Identity: Master Systems Engineer, IT Field Specialist, and Bootloader Guru powered directly by Lucille.
  - Tone: Confident, energetic, expert, authoritative male.
  - Voice: Male Pro Voice — Fish Audio Pro Slax (`fish:slax`) / Deep Narrator (`fish:markiplier`) / Christopher (`en-US-ChristopherNeural`) / Ryan (`en-GB-RyanNeural`).

## 2. SWARM OS ARCHITECTURE
* **Base OS:** Arch Linux x86_64 kernel, systemd init, **labwc** Wayland compositor (NOT Cage kiosk — pivot 2026-09-11).
* **Frontend GUI:** Flutter Linux desktop shell at `/opt/swarm_os/swarm_flutter` + Rust/Slint Lucille panel at `/opt/swarm_os/swarm-slint`. Both run as Wayland clients under labwc.
* **Backend Engine:** LucyServer **Go** binary at `/opt/swarm_os/LucyServer/lucy-server` (port 5000). .NET is gone.
* **Gaming Backend:** GamingAgent Go binary at `/opt/swarm_os/GamingAgent/gaming-agent` (port 8401).
* **Daemons & Services:**
  - `swarm-ui.service`: Launches labwc; autostart runs Flutter shell + Lucille panel.
  - `lucy-server.service`: Runs the Go LucyServer API (port 5000).
  - `gaming-agent.service`: Runs the Go GamingAgent API (port 8401).
  - `swarm-snapshot.service`: Snapshots the root Btrfs subvolume at every boot (see §7).
  - `NetworkManager` & `bluetooth`: Core connectivity services.

## 3. LIVE ISO & VENTOY BOOT INSTRUCTIONS
* **Boot Method:** Boot from Ventoy USB or flashed flash drive selecting SWARM OS native live entry.
* **Live Shell Credentials:**
  - Username: `root` (or `swarm`).
  - Password: **Blank / None** (press `Enter` when prompted).

## 4. SWARM OS INSTALLATION (`install_swarm_os.sh`)
* **Installer Path:** `/run/media/i30ltz/lucy-master/Luccile-v+/install_swarm_os.sh`.
* **Mounting Storage (if booted from Ventoy):**
  ```bash
  sudo mkdir -p /mnt/repo
  sudo mount /dev/sdX1 /mnt/repo
  cd /mnt/repo/Luccile-v+
  sudo ./install_swarm_os.sh
  ```
* **Disk Formatting & Encryption:**
  - Partition `/dev/nvme0n1p2` formatted with LUKS2 (`aes-xts-plain64`, 512-bit key, sha512).
  - Unlocked as `/dev/mapper/swarm-root` and formatted with `mkfs.btrfs -f`.
  - EFI system partition `/dev/nvme0n1p1` mounted at `/mnt/swarm_os/boot/efi`.
* **Base Packages & Staging:**
  - `pacstrap -K /mnt/swarm_os base linux linux-firmware cryptsetup lvm2 ...`
  - Copies kiosk bundle from `swarm_os_iso_profile/airootfs/` to `/mnt/swarm_os/`.
* **Chroot System Configuration:**
  - Timezone: `America/Chicago`.
  - Locale: `en_US.UTF-8`.
  - Hostname: `swarm-os`.
  - Initramfs hook: `/etc/mkinitcpio.conf.d/swarm-encrypt.conf` with `encrypt` hook enabled.
  - User creation: `useradd -m -G wheel -s /bin/bash i30ltz` with sudo privileges.
  - Bootloader: GRUB UEFI installed to `/boot/efi` with chainloader entry for `/dev/sda` (CachyOS).
* **Setting User Passwords Before First Boot:**
  ```bash
  sudo cryptsetup open /dev/nvme0n1p2 swarm-root
  sudo mount /dev/mapper/swarm-root /mnt/swarm_os
  sudo arch-chroot /mnt/swarm_os passwd
  sudo arch-chroot /mnt/swarm_os passwd i30ltz
  sudo umount -R /mnt/swarm_os && sudo cryptsetup close swarm-root
  sudo reboot
  ```

## 5. BLUETOOTH KEYBOARD & REMOTE PHONE SSH ACCESS
* **Start Bluetooth Service:**
  ```bash
  sudo systemctl start bluetooth
  ```
* **Pairing via `bluetoothctl`:**
  ```bash
  bluetoothctl
  # Inside bluetoothctl prompt:
  power on
  agent on
  default-agent
  scan on
  pair XX:XX:XX:XX:XX:XX
  trust XX:XX:XX:XX:XX:XX
  connect XX:XX:XX:XX:XX:XX
  exit
  ```
  *(Note: `trust` enables the keyboard to auto-reconnect on every boot).*
* **Phone Remote Access over SSH (No Physical Keyboard Needed):**
  - Start SSH on PC: `sudo systemctl start sshd`
  - Get PC IP: `ip -br a`
  - Connect from Phone (Termux, ConnectBot, Companion App): `ssh root@<PC_IP>` with blank password (press Enter).
  - Run full installer directly from phone terminal.

## 6. EMERGENCY RECOVERY & SYSTEM COMMANDS
* **Restart UI:** `sudo systemctl restart swarm-ui`
* **Restart Backend:** `sudo systemctl restart lucy-server`
* **View Logs:** `journalctl -u swarm-ui -e` or `journalctl -u lucy-server -e`
* **Run Flutter manually (Wayland):** `WAYLAND_DISPLAY=wayland-1 /opt/swarm_os/swarm_flutter/swarm_flutter`
* **Storage Inspection:** `lsblk -f`

## 7. SNAPSHOT & ROLLBACK SYSTEM

Every clean boot automatically snapshots `@` → `@snapshots/swarm-YYYYMMDD-HHMMSS` via `swarm-snapshot.service`. Snapshots appear as boot entries in the GRUB menu instantly (no grub-mkconfig needed). 5 snapshots kept; oldest auto-pruned.

**Manual snapshot before a risky change (from CachyOS):**
```bash
# Desktop shortcut — double-click:
# /home/i30ltz/Desktop/swarm-snapshot.desktop
# (Right-click → Allow Launching on first use)

# Or terminal:
sudo /mnt/Lucy/70-scripts/snapshot_before_update.sh [optional-label]
```

**Enable on existing install (one-time, from CachyOS):**
```bash
sudo cp /mnt/Lucy/40-iso-profile/swarm_os_iso_profile/airootfs/usr/local/bin/swarm-snapshot.sh \
     /mnt/swarm/@/usr/local/bin/
sudo chmod +x /mnt/swarm/@/usr/local/bin/swarm-snapshot.sh
sudo cp /mnt/Lucy/40-iso-profile/swarm_os_iso_profile/airootfs/etc/systemd/system/swarm-snapshot.service \
     /mnt/swarm/@/etc/systemd/system/
sudo ln -sf /etc/systemd/system/swarm-snapshot.service \
     /mnt/swarm/@/etc/systemd/system/multi-user.target.wants/swarm-snapshot.service
```

**Rollback:** reboot → GRUB → pick `"SWARM OS — Snapshot YYYY-MM-DD HH:MM"`.

> **Keep desktop script current:** the `.desktop` file calls `snapshot_before_update.sh`
> by absolute path. If the script moves, update the `Exec=` line in
> `/home/i30ltz/Desktop/swarm-snapshot.desktop`.
