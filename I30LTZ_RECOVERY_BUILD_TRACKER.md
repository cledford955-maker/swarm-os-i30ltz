# I30LTZ Recovery — Build Tracker

> **Official names (exact capitalization, used everywhere — code, UI, docs, services):**
> AI identity → **DR. I30LTZ**   |   Program → **I30LTZ Recovery**   |   Suite → **SWARM OS**

Auto-refreshed by `70-scripts/update_build_tracker.sh`. Run it after every build.

---

## Component Registry

_Last updated: 2026-09-12 20:30_

### UI Layer

| Component | Language | Version | Built | Size | SHA256 (first 16) |
|---|---|---|---|---|---|
| DR. I30LTZ Recovery | Rust + Raylib | 0.1.0 | 2026-09-12 12:36 | 2.7M | `cc8e005f6fc56557` |
| Lucille Panel (swarm-slint) | Rust + Slint | 6.2.44 | 2026-09-12 13:01 | 41M | `a5de410c76556d69` |
| Flutter Shell (frontend) | Dart / Flutter | 6.2.44+44 | — | — | staged in ISO |

### Backend Services

| Component | Language | Version | Built | Size | SHA256 (first 16) | Port |
|---|---|---|---|---|---|---|
| LucyServer-go | Go 1.26 | 6.2.44 | 2026-09-12 13:01 | 14M | `00ce69e434e41690` | 5000 |
| GamingAgent-go | Go 1.23 | 6.2.44 | 2026-09-12 13:02 | 18M | `3566e2d2383e2acb` | 8401 |
| GoogleWorkspaceService | .NET 10 / C# | 6.2.44 | ISO build | — | staged in ISO | 5002 |
| lucille-core | C++20 | — | 2026-09-08 18:22 | 628K | `050a37521867a268` | native lib |

### ISO / OS

| Component | Version | Date | Notes |
|---|---|---|---|
| SWARM OS ISO | 6.2.44 | 2026-09-12 20:30 | `10-releases/` — auto-bumped on build |
| Arch packages.x86_64 | — | 2026-09-12 | aspnet-runtime-10.0 added |

### Scripts

| Script | Last Updated | Notes |
|---|---|---|
| `build_swarm_iso_6.2.19_2026-09-08.sh` | 2026-09-12 | Builds all components + ISO |
| `sync_lucille_ai.sh` | 2026-09-12 | rsync --checksum, Lucille-AI + I30LTZ-Recovery |
| `update_build_tracker.sh` | 2026-09-12 | Regenerates this file |
| `unlock_slick.sh` | 2026-09-12 | Opens LUKS slick partition |
| `install_swarm_os.sh` | 2026-09-12 | Live USB → NVMe installer |

---

## Binary Locations by OS

One PC, one OS at a time. sdb8 (`/mnt/boltz`) is mounted by all three.

| OS | Boot Drive | DR. I30LTZ Recovery | LucyServer | Notes |
|---|---|---|---|---|
| SWARM OS | nvme0n1p4 | `/opt/swarm_os/i30ltz-recovery` | `/opt/swarm_os/LucyServer/lucy-server` | Primary OS |
| Endeavor | sdb4 (Ventoy) | `/mnt/boltz/I30LTZ-Recovery/i30ltz-recovery` | bring up LucyServer manually | Recovery boot |
| CachyOS | nvme0n1p1 | `/mnt/Lucy/30-source/i30ltz-recovery/target/release/i30ltz-recovery` | build from source or use boltz drive | Daily driver |

**All three mount sdb8 → `/mnt/boltz`** for shared AI binary + Lucille-AI reference.

---

## Sync Status

| Target | Path | Method | Last Synced |
|---|---|---|---|
| sdb8 (`/mnt/boltz`) | `/mnt/boltz/Lucille-AI/` | `rsync -a --checksum --no-delete` | see log below |
| sdb8 (`/mnt/boltz`) | `/mnt/boltz/I30LTZ-Recovery/` | `rsync -a --checksum` + sha256 manifest | see log below |
| sda4 (lucy-master LUKS) | `/mnt/lucy-master-backup/Lucille-AI/` | same | only when LUKS unlocked |
| sda4 (lucy-master LUKS) | `/mnt/lucy-master-backup/I30LTZ-Recovery/` | same | only when LUKS unlocked |

### Verify Integrity (any OS after mounting sdb8)

```bash
sha256sum -c /mnt/boltz/I30LTZ-Recovery/SYNC_MANIFEST.sha256
```

### Run DR. I30LTZ Recovery

```bash
# From sdb8 (Endeavor / CachyOS):
LUCY_URL=http://127.0.0.1:5000 SWARM_AUTH_TOKEN=swarm-token-2026 \
  /mnt/boltz/I30LTZ-Recovery/i30ltz-recovery

# From SWARM OS (via systemd):
systemctl start i30ltz-recovery

# Build from source:
cd /mnt/Lucy/30-source/i30ltz-recovery && cargo build --release
```

---

## UI Version Labels

Every UI surface displays its version + build date. Do not omit these.

| Surface | Where displayed | Format |
|---|---|---|
| DR. I30LTZ Recovery header | top-right corner | `v0.1.0  \|  2026-09-12` |
| DR. I30LTZ Recovery footer | bottom-right | `DR. I30LTZ Recovery  v0.1.0  \|  2026-09-12` |
| SWARM OS lock screen | bottom of screen | version from Flutter `pubspec.yaml` |
| Lucille Panel (slint) | status bar | `SWARM_VERSION` baked at compile time |
| LucyServer `/api/version` | REST endpoint | returns build version + date |

---

## Build Commands (Reference)

```bash
# DR. I30LTZ Recovery (bakes BUILD_DATE at compile time):
cd /mnt/Lucy/30-source/i30ltz-recovery && cargo build --release

# All components + ISO:
/mnt/Lucy/70-scripts/build_swarm_iso_6.2.19_2026-09-08.sh

# Sync all binaries to sdb8 + sda4 with checksums:
sudo /mnt/Lucy/70-scripts/sync_lucille_ai.sh

# Regenerate this build tracker:
/mnt/Lucy/70-scripts/update_build_tracker.sh
```

---

## Sync Log

_Appended by `sync_lucille_ai.sh` on each run._
