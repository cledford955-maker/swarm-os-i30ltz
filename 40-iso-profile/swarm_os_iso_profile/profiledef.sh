#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="swarm-os-v6.2.54-cc49de3a"
iso_label="SWARM_OS_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="SWARM OS <https://github.com/swarm>"
iso_application="SWARM OS · Lucille v6.2.54"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="swarm"
buildmodes=('iso')
bootmodes=('bios.syslinux'
           'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/group"]="0:0:644"
  ["/root"]="0:0:750"
  ["/root/.gnupg"]="0:0:700"
  ["/home/swarm"]="1000:1000:750"
  ["/home/swarm/.bash_profile"]="1000:1000:644"
  ["/home/swarm/.config"]="1000:1000:750"
  ["/home/swarm/.config/labwc"]="1000:1000:750"
  ["/home/swarm/.config/labwc/autostart"]="1000:1000:755"
  ["/opt/swarm_os"]="1000:1000:755"
  ["/opt/swarm_os/swarm_flutter"]="1000:1000:755"
  ["/opt/swarm_os/LucyServer"]="1000:1000:755"
  ["/usr/local/bin/install_swarm_os.sh"]="0:0:755"
  ["/usr/local/bin/swarm-snapshot.sh"]="0:0:755"
  ["/usr/local/bin/swarm-memory"]="0:0:755"
  ["/usr/bin/lucille-core"]="0:0:755"
  # Sealed secrets (2026-09-12, v1.0.0). The plaintext /etc/swarm_os.env is
  # gone for good — it used to put every API key in every ISO. Only the
  # AES-256 blob ships now; swarm-secrets.service unseals it into tmpfs.
  ["/etc/swarm_os.env.gpg"]="0:0:600"
  ["/etc/swarm_os.env.manifest"]="0:0:644"
  ["/usr/local/bin/swarm-unseal-secrets"]="0:0:755"
  ["/etc/systemd/system/swarm-secrets.service"]="0:0:644"
  ["/etc/subuid"]="0:0:644"
  ["/etc/subgid"]="0:0:644"
  # Live-boot swarm user is in the wheel group but had no sudoers rule
  # enabling it, so `sudo install_swarm_os.sh` failed at first boot
  # (found 2026-09-14). This grants wheel sudo from boot; the installer
  # still re-applies/hardens the same rule on the target system.
  ["/etc/sudoers.d/10-wheel"]="0:0:440"
  ["/etc/containers"]="0:0:755"
  ["/etc/containers/registries.conf"]="0:0:644"
  ["/etc/containers/storage.conf"]="0:0:644"
  ["/etc/profile.d/swarm-podman-docker.sh"]="0:0:755"
  ["/etc/systemd/system/swarm-podman-linger.service"]="0:0:644"
  ["/etc/apparmor.d/opt.swarm_os.GamingAgent.gaming-agent"]="0:0:644"
  ["/etc/apparmor.d/opt.swarm_os.LucyServer.lucy-server"]="0:0:644"
  ["/home/swarm/.config/systemd"]="1000:1000:750"
  ["/home/swarm/.config/systemd/user"]="1000:1000:750"
  ["/home/swarm/.config/systemd/user/sockets.target.wants"]="1000:1000:750"
  # google_tokens/credentials.json is NOT listed here on purpose: it's a
  # runtime artifact written only after the user completes Google OAuth —
  # it doesn't exist in the airootfs at build time. mkarchiso's
  # file_permissions resolves every listed path with realpath before
  # chmod'ing it; a nested path whose parent directory doesn't exist yet
  # resolves outside the expected tree and mkarchiso aborts with "Outside
  # of valid path" instead of the graceful "does not exist" warning it
  # gives for a plain missing entry (found 2026-09-13). google-workspace.
  # service now creates the directory itself via ExecStartPre, same
  # pattern as gaming-agent.service/lucy-server.service and /etc/swarm_os.
)
