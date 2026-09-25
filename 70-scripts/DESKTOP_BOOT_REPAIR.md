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
- ~~Fix desktop session teardown~~ — source fix 2026-09-25, see below; still
  needs a guest/boot verification. Automatic SIGHUP restarts were **not** added.

## Session teardown fix — 2026-09-25 (source + tests; not yet boot-verified)

Deliberately killing the dbus session launcher had left labwc/Flutter running.
Cause: `PAMName=login` makes pam_systemd move the launched desktop into a
logind `session-N.scope`; only `(sd-pam)` stays in `swarm-ui.service`'s cgroup,
so `KillMode=control-group` never reaches the desktop, and
`KillUserProcesses=no` leaves the scope running as an abandoned session.

A later same-day edit had added `pkill -u swarm -x labwc|swarm_flutter` lines.
Those missed `swarm-slint` (also autostarted) and hardcoded `swarm`, although
the installer rewrites the unit to `User=i30ltz`. Replaced by
`/usr/lib/swarm/swarm-ui-cleanup.sh`, run as `ExecStartPre=+` and first
`ExecStopPost=+` (before the tty reset). It reads the desktop user from the
unit, terminates that user's tty1/VT1 logind sessions (closing ones included),
escalates to SIGKILL after 3 s, and only then falls back to killing the three
kiosk-only program names.

The same edit also made `/usr/bin/swarm-session` start Gamescope whenever it
was installed, with flags gamescope 3.16.25 rejects (`unrecognized option
'--width'`, exit 1). Any system with gaming packages would have lost the desktop
to the text getty. Gamescope is now opt-in (`SWARM_GAMESCOPE=1`) with flags the
real binary accepts; labwc nested in Gamescope is still unverified.

`.gitignore` excluded all of `airootfs/usr/lib/`, so none of the hand-written
`usr/lib/swarm/` scripts (including `epp-tune.sh`) were in git; now tracked.

Verified: 11 boot-contract tests with stubbed loginctl/systemctl/pkill (session
selection, installer user rewrite, SIGKILL escalation, fallback coverage, unit
ordering, launcher default/opt-in, flags checked against the host's real
`gamescope --help`), and the real gamescope parsing the new flag set.
**Not verified:** real logind behaviour in a guest. The VM check was stopped
at root login. Next check: in a booted guest, `kill -9` the swarm-ui main PID,
then confirm `loginctl list-sessions` and `pgrep -u swarm labwc` are empty and
a restart yields exactly one compositor.

Regression check: `python3 70-scripts/tests/test_desktop_boot_contract.py`.
The canonical builder runs it before version stamping or privileged work.
It protects tty ownership, ordered handoff, and packaged executable permissions.
Local VM logs/screenshots are under `80-vm/boot-repair-20260924/` and gitignored.

Reference: [systemd logind ReserveVT semantics](https://cgit.freedesktop.org/systemd/systemd/tree/man/logind.conf.xml).
