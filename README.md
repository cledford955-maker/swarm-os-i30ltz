# LUCILLE — SWARM OS working drive
`layout v1.0.0 · 2026-09-07 · SWARM OS v6.2.19`

This partition holds everything needed to **run** SWARM OS. The encrypted
master drive (`lucy-master`, LUKS) remains the source of truth for history;
this drive is the live working copy.

## Layout

| Folder | Holds |
|---|---|
| `00-CURRENT/` | Symlinks to the newest of everything. **Start here.** |
| `10-releases/` | Built ISOs, one dated+versioned folder each, with sha256 |
| `20-runtime/` | Everything needed to RUN: `app/`, `bin/`, `LucyServer/`, `config/.env` |
| `30-source/` | Source trees: `frontend/`, `lucille-core/`, `LucyServer/`, companion |
| `40-iso-profile/` | archiso profile (`profiledef.sh`, `packages.x86_64`, `airootfs/`) |
| `50-boot/` | GRUB themes, rEFInd icons, boot assets |
| `60-boltz-brain/` | **Lucille's memory.** Identity, core facts, sessions, knowledge |
| `70-scripts/` | Build, restore, VM and sync scripts |
| `80-vm/` | QEMU/OVMF assets, `run_vm.sh`, qcow2 disks |
| `90-docs/` | Guides, reviews, manifests |
| `99-archive/` | Superseded versions and personal files — never deleted, just parked |

Numbers sort the folders into the order you actually use them, so `ls` reads
top to bottom as: what's current, what shipped, what runs, what builds it.

## Naming convention

Every versioned file carries a version **and** a date:

    <name>_v<major>.<minor>.<patch>_<YYYY-MM-DD>.<ext>

    build_swarm_iso_v6.2.19_2026-09-07.sh
    swarm-os-v6.2.19_2026-09-03_a1b2c3d4.iso
    boltz_identity_v1.0.0_2026-09-07.md

Superseded files move to `99-archive/superseded/` with their original date.
Nothing is overwritten in place, and nothing is deleted.

## Finding the newest thing

    ls -l 00-CURRENT/                 # symlinks to current everything
    ls -t 10-releases/                # releases, newest first
    cat 90-docs/MANIFEST_*.md         # dated inventory

## Rebuilding

    ./70-scripts/build_swarm_iso_v6.2.19_2026-09-07.sh

Requires `30-source/` and `40-iso-profile/` to be populated — see
`70-scripts/restore_from_lucy-master_v1.0.0_2026-09-07.sh`.

## Security note

**No API keys on this drive.** `20-runtime/config/.env` is a symlink to
`~/Documents/.env` (chmod 600, 25 keys). The real file never travels with the
drive and is never offered to Syncthing. See `20-runtime/config/README.md` for
how the app resolves it at runtime.

`99-archive/_personal/` holds a Proton recovery-phrase PDF that should be moved
off this drive entirely.
