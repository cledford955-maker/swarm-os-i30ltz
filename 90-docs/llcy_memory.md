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
* **Base OS:** Arch Linux x86_64 kernel, systemd init, Cage Wayland kiosk.
* **Frontend GUI:** Flutter Linux desktop client located at `/opt/swarm_os/swarm_flutter`.
* **Backend Engine:** LucyServer .NET 8 Web API located at `/opt/swarm_os/LucyServer`.
* **Daemons & Services:**
  - `swarm-ui.service`: Launches cage kiosk running the Flutter desktop interface.
  - `lucy-server.service`: Runs the ASP.NET Core LucyServer API.
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
* **Disk Formatting & Storage:**
  - Partition `/dev/nvme0n1p2` formatted directly with `mkfs.btrfs -f` (standard non-LUKS Btrfs root).
  - Mounted directly at `/mnt/swarm_os`.
  - EFI system partition `/dev/nvme0n1p1` mounted at `/mnt/swarm_os/boot/efi`.
* **Base Packages & Staging:**
  - `pacstrap -K /mnt/swarm_os base linux linux-firmware cryptsetup lvm2 ...`
  - Copies kiosk bundle from `swarm_os_iso_profile/airootfs/` to `/mnt/swarm_os/`.
  - Copies custom GRUB theme from `grub_themes/swarm_os` to `/mnt/swarm_os/boot/grub/themes/swarm_os`.
* **Chroot System Configuration:**
  - Timezone: `America/Chicago`.
  - Locale: `en_US.UTF-8`.
  - Hostname: `swarm-os`.
  - Initramfs hook: `/etc/mkinitcpio.conf.d/swarm.conf` with standard hooks (no encrypt hook).
  - User creation: `useradd -m -G wheel,video,render -s /bin/bash i30ltz` with sudo privileges.
  - Bootloader: GRUB UEFI installed to `/boot/efi` with direct `root=UUID=...` parameter and chainloader entry for `/dev/sda` (CachyOS).
* **Setting User Passwords:**
  - The installer prompts interactively for `root` and `i30ltz` passwords before finalizing.
  - Manual chroot (if needed later):
    ```bash
    sudo mount /dev/nvme0n1p2 /mnt/swarm_os
    sudo arch-chroot /mnt/swarm_os passwd
    sudo arch-chroot /mnt/swarm_os passwd i30ltz
    sudo umount -R /mnt/swarm_os
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
* **Restart UI Kiosk:** `sudo systemctl restart swarm-ui`
* **Restart Backend:** `sudo systemctl restart lucy-server`
* **View Logs:** `journalctl -u swarm-ui -e` or `journalctl -u lucy-server -e`
* **Run UI Manually:** `cage -d /opt/swarm_os/swarm_flutter`
* **Storage Inspection:** `lsblk -f`
* **GRUB Config Regeneration:** `sudo arch-chroot /mnt/swarm_os grub-mkconfig -o /boot/grub/grub.cfg`
