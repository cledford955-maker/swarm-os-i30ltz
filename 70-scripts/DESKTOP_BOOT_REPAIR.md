# Desktop boot repair — 2026-09-24

Reproduced the kiosk-to-text fallback using the existing Ventoy ISO
`swarm-os-v6.2.70-622e4129-2026.09.22-x86_64.iso` in an isolated QEMU/OVMF VM.
No host disks were attached. The newer physical-boot log
`logs/swarm-ui-20260924-074819.log` also records the launcher dying from SIGHUP.

## Confirmed causes and staged fixes

1. `99-swarm-seat.conf` reserved tty1 for automatic text logins while
   `swarm-ui.service` also claimed tty1. The VM journal showed getty starting
   and restarting during desktop startup, followed by the desktop's SIGHUP exit.
   Reserving tty6 instead stopped the collision. Added explicit service ordering
   after getty and Plymouth release the terminal.
2. The ISO's Flutter executable was mode 0644 and autostart reported Permission
   denied. The installed mkarchiso copies with `--no-preserve=ownership,mode`;
   source chmod alone does not survive packaging. Added explicit `file_permissions`
   entries for Flutter, overlay, GoogleWorkspaceService, overlay toggle,
   diagnostics, and the wake-listener script.

Canonical service and logind files were transferred into the disposable guest's
RAM overlay and executable modes corrected there. Both desktop processes ran;
the Flutter splash screen rendered. Guest loopback `/health` returned HTTP 200
for LucyServer (5000) and GamingAgent (8401). Watchdog settings read 30 seconds
and 5 minutes, but the VM has no hardware watchdog device, so hardware verification
remains open. This existing ISO boots with `apparmor=0`; these results do not
verify an AppArmor-enabled release.

## Remaining work

- Build and boot a fresh ISO through `70-scripts/build_swarm_iso.sh`; host sudo
  currently requires an interactive password. No new ISO was produced in this pass.
- Verify the desktop beyond its splash screen on real hardware.
- Fix desktop session teardown: deliberately killing the dbus session launcher
  left labwc/Flutter in logind session scopes outside the system service cgroup.
  A recovery prototype reproduced duplicate desktop processes and was removed.
  Automatic SIGHUP restarts were therefore **not** added to the final unit.

Regression check: `python3 70-scripts/tests/test_desktop_boot_contract.py`.
The canonical builder runs it before version stamping or privileged work.
It protects tty ownership, ordered handoff, and packaged executable permissions.
Local VM logs/screenshots are under `80-vm/boot-repair-20260924/` and gitignored.

Reference: [systemd logind ReserveVT semantics](https://cgit.freedesktop.org/systemd/systemd/tree/man/logind.conf.xml).
