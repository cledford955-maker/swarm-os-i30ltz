# SWARM OS — Graphical Installer

**Version:** 1.0.0 · **Date:** 2026-10-05 · **Base:** Arch archiso

Lucille-themed GUI front-end for `install_swarm_os.sh`. It does **not**
reimplement install logic — it collects the disk and password, then calls the
existing script in `--non-interactive` mode and streams its output live.

```
Browser (kiosk, localhost only)
   │  GET  /            wizard page, CSRF token injected
   │  GET  /api/disks   filtered lsblk enumeration
   │  POST /api/install validated → spawns installer
   │  GET  /api/log     Server-Sent Events, live transcript
   ▼
server.py  (python3, stdlib only — no pip)
   │  sudo -n  /usr/local/bin/install_swarm_os.sh \
   │             --disk <chosen> --non-interactive --password-file <0600>
   ▼
install_swarm_os.sh   ← 624 lines, unchanged
```

## Layout

```
swarm-installer-web/
├── VERSION                   1.0.0
├── README.md                 this file
├── server.py                 backend (stdlib only)
├── web/index.html            wizard UI, no external assets
├── bin/swarm-installer       launcher: server + kiosk browser
└── install-to-profile.sh     copies payload into the archiso profile
```

## Try it without building an ISO

```sh
SWARM_INSTALLER_DRYRUN=1 python3 server.py
# open the printed http://127.0.0.1:PORT/ URL
```

Dry run exercises every screen, the disk picker, validation and the live log
stream. No disk is touched and no privileged command runs.

## Install into the profile

```sh
bash install-to-profile.sh --dry-run     # preview
bash install-to-profile.sh               # apply
```

Idempotent. Backs up anything it replaces to `*.bak-YYYYMMDD-HHMM`. Appends
`python`, `chromium`, `cage` to `packages.x86_64` only if absent. Refuses to
run if the backend script is missing or lacks the flags it would be called with.

## Autostart on live boot

Add to `airootfs/etc/sway/config`:

```
exec --no-startup-id /usr/local/bin/swarm-installer
```

Otherwise launch it from the **Install SWARM OS** desktop entry.

## Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `SWARM_INSTALLER_DRYRUN` | `0` | `1` = simulate, never touch a disk |
| `SWARM_INSTALLER_PORT` | `0` (random) | fix the listen port |
| `SWARM_INSTALLER_SCRIPT` | `/usr/local/bin/install_swarm_os.sh` | backend path |
| `SWARM_INSTALLER_RUNDIR` | `/run/swarm-installer` | where the password file is staged |

## Safety properties

These are deliberate and tested — do not loosen them without reason.

- **Binds `127.0.0.1` only.** Requests from any other address get 403.
- **The live boot medium is excluded from targets.** Booted from Ventoy, that
  USB is an ordinary removable disk; offering it would let the installer wipe
  itself mid-run. Resolved via `/proc/self/mountinfo` against archiso, Debian
  live and casper mount hints.
- **Virtual devices excluded:** zram, loop, dm, sr, md, ram, nbd.
- **Disks under 8 GiB excluded** as too small.
- **Everything filtered is shown in the UI with its reason** — a missing disk
  is never a silent mystery.
- **Removable / read-only / LUKS-bearing / mounted disks are flagged**, not
  hidden; the operator still chooses explicitly.
- **Server-side disk re-validation.** The POSTed path must appear in a fresh
  enumeration and match `^/dev/[A-Za-z0-9/_-]+$`. The client cannot hand an
  arbitrary path to a destructive script.
- **Typed confirmation.** The operator retypes the exact disk path; the server
  checks it again independently of the browser.
- **Single-shot.** A second install request returns 409.
- **CSRF token** minted per server start, required on every POST.
- **Password never on a command line** (`/proc/<pid>/cmdline` is world
  readable). Written to a `0600` file in a `0700` dir, passed by path, read
  once and unlinked by the backend; zeroed by the server if the backend died
  early. Cleared from the DOM as soon as it is handed over.
- **Privilege is scoped to two commands** in sudoers: the installer script and
  `systemctl reboot`. Nothing else.
- **Reboot requires a finished install** — returns 409 otherwise, so a stray
  request cannot kill a running install.

## Known limits

- Needs a browser in the ISO. `install-to-profile.sh` adds `chromium` + `cage`.
  If neither is present the launcher prints the URL and keeps the backend up so
  a manually-opened browser still works.
- The account name is fixed to `i30ltz` by the backend script; the GUI shows it
  read-only rather than pretending it is configurable.
- Locale, keyboard and timezone are not collected — the backend does not accept
  them. Add there first if wanted, then surface here.
