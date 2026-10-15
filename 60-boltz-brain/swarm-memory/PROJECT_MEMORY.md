# SWARM OS Shared Memory

_Generated 2026-10-15 03:00 UTC from 121 log entries. Do not edit — add memories with `swarm-memory add`, the companion app, or `POST /api/memory/entries`._

Log: `log/<device>.jsonl` (append-only, one file per device). Spec: `90-docs/SWARM_MEMORY_SYNC_v1.0.0_2026-09-16.md` in /mnt/Lucy.

## Devices

- `cachyos@cachyos-i30ltz` — 53 entries
- `copilot-test` — 1 entries
- `debian@debian` — 67 entries

## Decisions

### agent-claim-protocol
_cachyos@cachyos-i30ltz · 2026-09-25T08:24:37_

Multi-AI coordination (2026-09-25): before starting work from SWARM_OS_IMPLEMENTATION_CHECKLIST.md (the masterlist), mark the item [>] Item — CLAIMED by <agent> <YYYY-MM-DD HH:MM>. Other agents skip claimed items; a claim >24h old with no progress needs user OK before takeover. Replace the claim with [x]/[~] plus notes when done.

### android-persona-switch
_debian@debian · 2026-10-14T22:06:28_

Wired queryI30ltzChatApi into Lucille Assistant MainActivity.kt with voice playback (Adam voice) alongside Lucille (Lily voice). Persona toggle and chat routing in Android app now complete in code.

### api-keys-status
_debian@debian · 2026-10-14T20:11:12_

2026-10-14: OpenRouter and Steam API keys in /mnt/Lucy/20-runtime/.env WORK (both HTTP 200 against the providers, verified by swarm-claude). The user replaced them ~2026-10-05. Any brief saying 'keys dead / add OpenRouter + Steam keys' is stale; do not repeat it.

### app-build-partitions
_debian@debian · 2026-10-09T18:52:00_

2026-10-09 user decision: new mounts /mnt/lucillebuild (C. Lucille build, ext4 UUID 93037d5a-5b82-484c-ac20-28211c09e1c0) for the Lucille Assistant app, /mnt/boltzbuild (D. BOLTZ Recovery, NTFS UUID 67C2E9F8241FD7AE) for the i30ltz Recovery app, /mnt/recoveryos (Recovery OS root/home, btrfs UUID 490b9e60-afb2-45c6-91ce-2c6b1ea5a2f3, sdb3 Samsung T7, reformatted). Build partitions A swarmbuild/B recoverybuild/C lucillebuild/D boltzbuild are all on the 1.8TB Micron drive. Everything needed to build each app (source, toolchains, caches) lives on its own partition and built apps must stand alone (no dependence on /mnt/Lucy or any build tree). swarmbuild is now matched by UUID 5c84ef0e-d7b8-4b36-b1c4-58817b483dda (label became 'A. swarm-build'). Root script: sudo /mnt/Lucy/70-scripts/apply_app_build_mounts.sh. Rules: /mnt/Lucy/CLAUDE.md 'App build partitions'.

### boltzbuild-ext4
_debian@debian · 2026-10-09T19:25:17_

2026-10-09 user: /mnt/boltzbuild (sda9 'D. BOLTZ Recovery') was created NTFS by mistake - reformat it. Plan: ext4, label unchanged, fixed UUID e195839a-f617-4abd-9bf3-b64a679b7474 (PARTUUID 52545158-4886-4f7e-8fed-7556cebaaefd), applied with 'sudo /mnt/Lucy/70-scripts/apply_app_build_mounts.sh --reformat-boltz' (guarded: right PARTUUID, on the Micron, NTFS, empty). Also: SWARM OS must run standalone from the internal NVMe.

### cloud-models-and-verbal-voices
_debian@debian · 2026-10-14T21:04:56_

Cloud models and distinct verbal voices unified across Lucille and Dr. I30LTZ: Lucille uses Kimi (moonshotai/kimi-k3) with ElevenLabs Lily voice; Dr. I30LTZ uses Qwen Coder (qwen/qwen-2.5-coder-32b-instruct) with ElevenLabs Adam voice. Both fallback to local Ollama. Verified live on Debian :8403.

### companion-identity
_cachyos@cachyos-i30ltz · 2026-09-21T20:47:45_

Canonical spelling is I30LTZ (capital I, digit 3, digit 0, capital LTZ). Existing Android app remains the same installation/applicationId and is named I30LTZ Companion, paired with I30LTZ Recovery OS for OS installation, repair and data recovery. Its IDE must provide visible commits, persistent Git authentication, Android project/APK build workflows and ADB where supported. Lucille Assistant is a separate assistant/gaming phone app for SWARM; do not fold it into I30LTZ Companion or rename infrastructure/database identifiers.

### debian-grub-entries
_debian@debian · 2026-10-10T22:20:27_

Debian GRUB menu entries refreshed 2026-10-10: swarm-grub/entries/20_swarm_entries (install with: sudo bash swarm-grub/install.sh --with-entries) chainloads SWARM OS (ESP FE19-A70F, \EFI\SWARM_OS\grubx64.efi), Recovery OS (own ESP A367-87E3, \EFI\i30ltz\shimx64.efi) and Ventoy (626B-4255 / label VTOYEFI); CachyOS removed; os-prober disabled to avoid duplicates. Verified in QEMU with stand-ins only; real boots untested.

### debian-grub-theme
_debian@debian · 2026-10-10T22:01:10_

User chose the new swarm-grub theme (/mnt/Lucy/swarm-grub, built 2026-10-10) as the look of DEBIAN's GRUB menu over the older swarm_dev theme (which was never installed). Theme-only installer: sudo bash swarm-grub/install.sh (--dry-run, --uninstall); not installed yet, needs sudo + reboot. Menu entries (grub_themes/09_swarm_debian) are a separate, still-stale piece.

### debian-tailscale-ip
_debian@debian · 2026-10-10T00:26:42_

Update 2026-10-09 (user said go ahead): LucyServer drop-in ~/.config/systemd/user/swarm-lucy-dev.service.d/listen.conf now binds http://127.0.0.1:5000;http://100.82.1.19:5000 (was .21; backup listen.conf.bak-20261009-202628). The swarm-lucy-dev user unit is disabled and was NOT started. Only the frozen 30-source/LucilleAssistant copy in /mnt/Lucy still mentions .21; leave it.

### dev-host-cachy-to-debian
_debian@debian · 2026-10-08T02:02:14_

SWARM OS primary development environment transitioned from CachyOS to Debian 13 (trixie). Dev dependencies, Docker mkarchiso bridge, user timers, and dev daemons configured on Debian host.

### gaming-agent-hardening
_debian@debian · 2026-10-14T21:32:02_

SW-05 resolved in GamingAgent-go: context cancellation on Eval/Chat/callChat, database ping health check (503 on failure), PriceAlertDaemon pace delay and stop guard, weather cache TOCTOU fix, and unit test coverage added for db, handlers, and models (all passing).

### gemini-daily-brief-and-audit
_debian@debian · 2026-10-07T21:10:06_

Gemini 3.8 Flash performed the 2026-10-07 daily project brief and comprehensive audit for SWARM OS (v6.2.83). Audited backend tests, confirmed GLIBC version boundary on Debian host, verified mount layout shifts, and synced output documents to drive (/mnt/storage/drive/SWARM_OS/).

### grub-theme-pair
_cachyos@cachyos-i30ltz · 2026-09-19T16:41:31_

User selected green mechanical-wasp monitor for CachyOS and blue METALWASP for SWARM. Both need CachyOS, SWARM OS, EndeavourOS and Ventoy with matching 96px glossy icons. Cachy icon must be a cyan C, not an Arch triangle. Prepared and GRUB-render-tested in /mnt/Lucy/grub_themes; installed-system activation pending sudo /mnt/Lucy/70-scripts/install_dual_grub_themes.sh.

### hitl-push-design
_cachyos@cachyos-i30ltz · 2026-09-25T14:02:10_

HITL approvals to phone (2026-09-25, user chose foreground service over FCM): I30LTZ Companion HitlApprovalService keeps an authenticated WebSocket to lucille-core ws://<host>:9091 (X-Swarm-Auth = SWARM_AUTH_TOKEN, same as LucyServer). Deny = one tap from the notification; Approve requires the review screen + biometric/screen lock. No answer = denied. lucille-core engine starts :9091 only when SWARM_AUTH_TOKEN is set to a non-public value; SwarmRouter high-risk diffs need 2-of-2 consensus AND a human approver.

### hourly-autocommit-all-4-repos
_debian@debian · 2026-10-08T05:00:28_

Configured 1-hour auto-commit and push timers on Debian host for all four repositories: SWARM OS (/mnt/Lucy), Lucille Assistant (/mnt/Lucy/lucille-companion subtree), Recovery OS (/mnt/recoverybuild), and Recovery Companion (/mnt/recoverybuild/I30LTZ-Recovery-companion). Both swarm-lucy-sync.timer and recovery-sync.timer active at OnUnitActiveSec=1h.

### lucille-app-boltz-parity
_debian@debian · 2026-10-10T10:53:30_

2026-10-10 update: Lucille Assistant 1.4.0 closes the earlier open items. The 1307 hardcoded auth bypass (a real backdoor - worked over Tailscale regardless of SWARM_AUTH_TOKEN) is removed (regression test added). PC-control command link shipped as a FIXED allowlist only (check-mounts, restart-lucyserver, drop-ram-caches, reboot-pc, shutdown-pc; actions.go) - sudo actions use 'sudo -n' and need a manually-installed NOPASSWD rule (lucille-assistant actions sudoers-template), nothing runs as root by default. A first design letting a phone send an arbitrary sudo command (even password-gated) was never built - this session's safety layer correctly refused it as an RCE surface. Device pairing shipped (pairing.go): 'lucille-assistant pair' prints a 6-digit one-device one-use 10-min code (same shape as i30ltz-node pair), phone enters it once in Settings and gets its own permanent token independent of SWARM_AUTH_TOKEN, so rotating the PC's main token no longer breaks paired phones. 'lucille-assistant devices list|revoke' manage them; only a SHA-256 hash is stored. Generating a code is loopback-only even for a remote caller holding the real token; redeeming one works from anywhere. All three real phones are still on 1.2.0 (installing the 1.4.0 APK on them was refused by the session's own safety layer and has not been retried) - they currently have NO remote access since the 1307 bypass they relied on is now closed server-side. Memory-sync scope is still open.

### lucille-assistant
_cachyos@cachyos-i30ltz · 2026-09-16T11:52:10_

Lucille Assistant v1.0.0 (2026-09-16): personal-assistant jobs (daily brief, meds/water/food/sleep nudges, project+gaming hours, git/drives, mail/calendar via GoogleWorkspaceService :8399, Linux/gaming news with no politics, Steam sales + CD-key prices, build ideas) live in a separate Go service on :8403 at 30-source/LucilleAssistant, not in LucyServer. Phones use it over Tailscale as a web app with SWARM_AUTH_TOKEN; a native companion tab comes next.

### lucille-briefings-status-format
_debian@debian · 2026-10-10T00:45:11_

2026-10-09 (user request): the Lucille Assistant briefings are status briefings: STATUS (dated, health colour), NEXT STEPS & SCHEDULE (each step [YOU] or [AI]), 3 SUGGESTIONS, REFERENCE, for SWARM OS / Recovery OS / I30LTZ Companion (Boltz Recovery, D) / Lucille Assistant. They are a snapshot: when a project's state changes, update its briefing (edit in the phone app, or PUT /api/briefings/<id> on :8403) and the seed/*.md copy under /mnt/lucillebuild/src/LucilleAssistant.

### lucille-core-consensus-gate
_cachyos@cachyos-i30ltz · 2026-09-25T12:24:34_

lucille-core 2-of-2 consensus gate (2026-09-25): wired into SwarmRouter::route_and_execute() between DeepSeek audit and checkpoint/apply. Fails closed — with no voters set (SwarmRouter::set_consensus_backends) every high-risk diff (systemd/firewall/sysctl/boot/caps) is blocked; a throwing voter is a reject. Classifier is case-insensitive and checks removed lines (earlier version never matched uppercase patterns — a CAP_SYS_ADMIN grant bypassed the gate).

### lucille-core-context-pruning
_cachyos@cachyos-i30ltz · 2026-09-25T08:24:37_

lucille-core context pruning (2026-09-25): EntropyFilter::prune_by_distance_dropoff cuts at the largest outlier gap between sorted cosine distances (gap > mean_gap + 1.5σ), not mean−1.5σ (that kept ~1 of 5 hits). Preserves RRF order; hybrid_search exempts keyword-only hits (dense_rank<0). Speculative pipeline takes real backends via SwarmRouter::set_pipeline_backends(); without them it runs mocks and sets PipelineResult.used_mock_backends. Compiler logs are EntropyFilter::clean()ed before GLM. Still open: real HTTP clients + engine IPC command.

### lucille-core-service
_cachyos@cachyos-i30ltz · 2026-09-25T17:36:01_

lucille-core runs on SWARM via airootfs lucille-core.service (enabled, User=swarm, EnvironmentFile=-/run/swarm_os.env for SWARM_AUTH_TOKEN, waits up to 30 s for tailscale0, IPC /run/lucille/ipc.sock, companion socket :9091). nftables already restricts :9091 to tailscale0.

### lucy-master-sync-removed
_debian@debian · 2026-10-11T21:48:19_

2026-10-11 (user): the Lucy <-> lucy-master two-way sync is removed (sync_lucy_master.sh + test deleted, never run for real; exception dropped from the never-write-to-lucy-master rule). /mnt/archive (lucy-master-bak) never had a sync. Lucy <-> swarmbuild sync and its engine stay. Do not re-create it unless the user asks. Untouched: sync_lucille_ai.sh still has a lucy-master (sda4, only if unlocked) leg.

### mount-check-and-sync-hazards
_debian@debian · 2026-10-08T01:49:30_

2026-10-07: check_mounts.sh now handles x-systemd.automount (was false MISSING; --fix would have duplicated the swarmbuild fstab line). sync_lucy_swarmbuild.sh to-lucy now uses --update and skips .git (it used to overwrite newer CLAUDE.md/tracker/.git in Lucy with older build-tree copies). On Debian the read-only lucy-master mirror (sdb3) is mounted rw at /mnt/archive - remount ro. OpenRouter and Steam keys returned HTTP 200 on 2026-10-07.

### nvidia-runtime-policy
_cachyos@cachyos-i30ltz · 2026-09-25T10:32:12_

SWARM OS NVIDIA policy (2026-09-25): current target is 16 GB RAM with Intel UHD integrated graphics and no NVIDIA GPU. Keep NVIDIA features on hosted HTTP APIs; do not add CUDA, cuDNN, TensorRT, NVIDIA drivers, NVIDIA Container Toolkit, or local NIM images to the base ISO. A future local NIM must run on a separate supported NVIDIA host after model-specific VRAM and platform validation. See 70-scripts/NVIDIA_RUNTIME.md.

### rc-10-sse-backend
_debian@debian · 2026-10-14T22:19:38_

Merged overlapping Recovery OS SSE backends into canonical FastAPI sse_bridge.py (port 7300): added /boltz SSE streaming, /health, /sse/events, ntfy approval callbacks, dual Bearer/X-Swarm-Auth auth, and graceful non-root fallback; updated boltz_server.py as unified entrypoint; 17 pytest unit tests pass; updated SOUL.md capability table.

### recovery-os-install-target
_debian@debian · 2026-10-08T03:30:03_

2026-10-07 user decision: Recovery OS is installed on the 931.5 GB disk — root on the former CachyOS partition (btrfs 'Cachy OS', UUID ef9acba2-3816-4fd7-bdd7-a9526816d3f0, sda3 on the Debian boot) and EFI on that disk's ESP (vfat 'EFI', UUID A367-87E3, sda1), directly beside the lucy-master LUKS volume (UUID a24202ce-4d76-4eb7-8923-8e8ddbacdaa7, sda4, /mnt/storage on Debian), which is never touched. Supersedes RC-11 (portable 1.8 TB drive, shared Debian ESP 362A-E48F). CachyOS is decommissioned. Not installed yet. Always target by UUID; sda/sdb letters swap between boots.

### recovery-os-install-target-correction
_debian@debian · 2026-10-08T03:34:29_

2026-10-07: sda3 filesystem state unverified - user was told it was reformatted to ext4 (uninstall_cachyos.sh does mkfs.ext4 -L reclaimed-dev); udev still showed btrfs Cachy OS ef9acba2. A reformat changes the fs UUID, so identify the Recovery OS target by GPT PARTUUID instead: sda3 993d0098-1b2f-44a2-b51d-11c2bfeddc40, ESP sda1 e25e5715-f3b8-4ddb-9796-d1c270804140 (fs A367-87E3), lucy-master sda4 20a96573-0c80-4393-ba95-40a64964b39e. sda3 ends exactly where sda4 begins. Confirm with: sudo blkid -p /dev/sda3.

### recovery-os-installed
_debian@debian · 2026-10-09T23:30:34_

2026-10-09: Recovery OS installed from Debian by install-recovery-from-debian.sh (user ran it). Root = sda3 btrfs 'Recovery OS' NEW UUID 71287bbf-81bf-4074-9619-4180b5a15742 (PARTUUID 993d0098-1b2f-44a2-b51d-11c2bfeddc40, subvols @ @home @snapshots). Standalone bootloader on its own ESP sda1 (A367-87E3): EFI/i30ltz/grubx64.efi + fallback EFI/BOOT/BOOTX64.EFI + firmware entry Boot0001 appended last (Debian Boot0003 first). Pending: root password, boot test with Debian drive unplugged, update Debian fstab /mnt/recoveryos UUID (still 490b9e60).

### recovery-os-root-btrfs
_debian@debian · 2026-10-08T03:38:19_

2026-10-07 user decision: Recovery OS root filesystem is btrfs (not ext4) on the former CachyOS partition, PARTUUID 993d0098-1b2f-44a2-b51d-11c2bfeddc40. uninstall_cachyos.sh (SWARM lane) now targets partitions by PARTUUID and formats btrfs label Recovery-OS after a typed-device-path confirmation; the old version formatted /dev/sda3 by letter as ext4, unsafe because sda/sdb letters swap between boots.

### recovery-os-standalone
_debian@debian · 2026-10-08T08:29:26_

2026-10-08 user decision: Recovery OS must be STANDALONE - boot with the Debian disk unplugged. Own bootloader on its own ESP (sda1, fs UUID A367-87E3, PARTUUID e25e5715-f3b8-4ddb-9796-d1c270804140): fallback EFI/BOOT/BOOTX64.EFI + EFI/i30ltz + firmware boot entry appended to BootOrder (never first). Debian itself boots from the other disk: sdb1 ESP 362A-E48F, Boot0003 debian -> EFI/debian/shimx64.efi, root sdb2. Recovery must not depend on Debian's GRUB/ESP/disk. Installer: /mnt/recoverybuild/70-scripts/install-recovery-from-debian.sh (not yet run).

### shared-memory-architecture
_cachyos@cachyos-i30ltz · 2026-09-16T09:31:17_

Shared memory v1.0.0 built 2026-09-16: append-only per-device logs at /mnt/brains/swarm-memory, cursor-based sync (not timestamps), Tailscale on :5000 plus token-only LAN listener on :8402 and a phone mesh via mDNS _swarmcompanion._tcp, 30 s write lease for live edits, Claude memory synced both ways, git mirror in 60-boltz-brain/swarm-memory. No Syncthing for memory. LAN listeners never run on the public fallback token.

### swarm-os-standalone
_debian@debian · 2026-10-09T19:30:20_

2026-10-09 user: SWARM OS must run completely off the internal NVMe (nvme0n1 p1 ESP, p2 root, p3 swap) and be standalone - no external drive may be a dependency; /mnt/Lucy p4, /mnt/brains p5 are optional. Audited installed system (0 FAIL); fixed image sources (swarm-ui logs -> /var/log/swarm-ui, parity timer conditional, stale external fstab entries removed). Scripts: /mnt/Lucy/70-scripts/check_swarm_standalone.sh (read-only) and make_installed_swarm_standalone.sh (sudo, patches installed root). Not yet boot-tested with externals unplugged.

### telemetry-daemon-9091
_cachyos@cachyos-i30ltz · 2026-09-25T12:42:50_

lucille-core :9091 TelemetryDaemon (2026-09-25): WebSocket upgrades require the mesh token (Authorization: Bearer / X-Swarm-Auth / ?token=); start() refuses empty or default 'swarm_mesh_secret_token'. Bind falls back to 127.0.0.1, never 0.0.0.0. 5 s ping, drop after 3 missed pongs. Plain HTTP GET stays an unauthenticated status JSON for health checks. Daemon is not launched by LucilleEngine yet. HITL phone push needs user decision: FCM vs Android foreground service.

## Facts

### companion-location
_cachyos@cachyos-i30ltz · 2026-09-25T14:02:10_

I30LTZ Companion source lives at /mnt/Lucy/30-source/android_companion/swarm_os-companion (restored 2026-09-25 from an accidental archive into 99-archive/companion-legacy-2026-09-25; the stale '(seperate-related-project)' copy stays archived).

### companion-subtree-sync-hazard
_cachyos@cachyos-i30ltz · 2026-09-25T17:36:01_

Resolved 2026-09-25: auto_sync_github.sh now pushes app repos (recovery, companion, assistant) as snapshot commits on top of each remote's main (commit-tree HEAD:<prefix> -p <remote tip>), not git subtree push. Never force-push these repos.

### companion-versioning
_cachyos@cachyos-i30ltz · 2026-09-25T17:36:01_

I30LTZ Companion versionCode must stay above 81 (6.2.21, installed 2026-09-25 on A67L Gen2 USB and Samsung SM-S176V wireless adb 192.168.1.116). Phones previously ran a 09-07 build numbered 80 while source said 73. Debug-keystore signed; adb install -r keeps data.

### lucille-core-open-bugs
_cachyos@cachyos-i30ltz · 2026-09-25T12:42:50_

lucille-core open bugs: none as of 2026-09-25 — router git-apply regression and IpcServer shutdown race fixed; test_engine 146 pass / 0 fail, ThreadSanitizer clean.

### sda3-filesystem-verified
_debian@debian · 2026-10-08T03:39:33_

2026-10-07 verified by the user with sudo blkid -p /dev/sda3: it is still btrfs, label 'Cachy OS', UUID ef9acba2-3816-4fd7-bdd7-a9526816d3f0, PARTUUID 993d0098-1b2f-44a2-b51d-11c2bfeddc40, 230 GiB. The earlier report that it was formatted to ext4 was wrong; nothing has been erased. Recovery OS root is to be btrfs; the UUID will change once it is formatted.

## Claude memory

### MEMORY.md
_debian@debian · 2026-10-15T01:21:37_

# Memory Index
- [lucy-master mount separation](feedback_lucy_mount_separation.md) — lucy-master is read-only source; /mnt/Lucy is the live working drive — never mix them
- [Mount points](project_mount_points.md) — 2026-10-09: /mnt/lucillebuild (Lucille Assistant), /mnt/boltzbuild (i30ltz Recovery, NTFS!), /mnt/recoveryos (sdb3 490b9e60) added, all builds on the 1.8TB drive, apps must stand alone. Older: Recovery OS will live on the old CachyOS partition (sda3 ef9acba2 + ESP sda1 A367-87E3) beside lucy-master (2026-10-07); /mnt/storage = unlocked lucy-master; build trees /mnt/swarmbuild, /mnt/recoverybuild
- [Lucille identity & vision](project_lucille_identity.md) — she is the AI the user made that STARTED the project, the AI Core, oversees their projects + therapy (user, 2026-10-12); stone+electric aesthetic, hex desktop, hidden uncensored mode, NOT a web app
- [SWARM OS journey & task list](project_swarm_journey.md) — the 10-task ordered roadmap: Boot→Security→Gaming→Coding; read TaskList each session to find the next task
- [packages.x86_64: no inline comments](feedback_packages_x86_64_no_inline_comments.md) — trailing comments on a package line break mkarchiso builds ("target not found") — comments must be their own line
- [sda/sdb drive letters swap between boots](feedback_disk_letter_instability.md) — never target install_swarm_os.sh by sdX letter or auto-detect; always `--disk /dev/nvme0n1`
- [user's shell is fish, not bash](feedback_user_shell_is_fish.md) — VAR=value / $(...) fails in their terminal; wrap bash-syntax commands in `bash -c '...'`
- [Shared memory across OSes/phones](reference_swarm_shared_memory.md) — /mnt/brains/swarm-memory log; read PROJECT_MEMORY.md; this dir syncs through it
- [Persona vs. infrastructure naming](feedback_persona_vs_infrastructure_naming.md) — before renaming a matched "Lucille"/"boltz" string, check it isn't a real filename/DB key/API value/network name
- [Multiple AI agents sometimes concurrent](project_multiple_ai_concurrent.md) — user sometimes has another AI actively working /mnt/Lucy at the same time, occasionally unintentionally — active mid-session changes may be theirs
- [Forge renamed Apex](project_forge_renamed_apex.md) — the coding IDE formerly "Forge" is now "Apex"; another AI is on it as of 2026-09-20, avoid that area
- [Auto-sync commits every ~10min](project_auto_sync_commits.md) — repo auto-commits everything on a timer — explains passive file drift between reads, not active concurrent work
- [Steam needs -cef-disable-gpu](project_steam_cef_crash.md) — Steam client crashes on launch on this CachyOS setup unless run with this flag; bake it into any future launcher
- [App build partitions](project_app_build_partitions.md) — 2026-10-09: PRODUCT MAP (A SWARM OS, B Recovery OS = OSes; C Lucille Assistant, D Boltz Recovery = phone apps connecting to both); each app builds on its own partition & stands alone; C at /mnt/lucillebuild; D (boltzbuild, ext4 UUID 6f7c7656…) holds the I30LTZ-Recovery-companion copy; old-copy deletions pending the user
- [SWARM OS standalone](project_swarm_os_standalone.md) — 2026-10-09 user requirement: installed SWARM OS must run off the internal NVMe alone; audited (0 FAIL, soft refs fixed in sources), check + patch scripts written, needs sudo run + real unplugged boot test
- [Read ALL project docs first](feedback_read_all_project_docs_first.md) — 2026-10-09: mislabelled D as the Rust app from one doc; check Lucy CLAUDE.md AND recoverybuild/00-CURRENT docs before moving/placing anything
- [Debian tailnet IP](reference_debian_tailscale_ip.md) — Debian dev PC = 100.82.1.19; baked into the phone app as a known machine (host only, no token)
- [Lucy↔swarmbuild two-way sync](project_lucy_swarmbuild_sync.md) — 2026-10-10: `sync_lucy_swarmbuild.sh both [--apply]` tells created from deleted; never plain-rsync the trees. The Lucy↔lucy-master sync was REMOVED 2026-10-11 (user) — don't recreate it
- [Phone terminal: sudo + copy/paste](project_phone_terminal_verified.md) — 2026-10-10: verified (real agent + emulator); agent 0.3.2 fixes empty session list; agent NOT running on Debian yet
- [Secure Boot + LUKS unlock plan](project_secureboot_luks_plan.md) — 2026-10-10 decision: Secure Boot on, TPM auto-unlock lucy-master (T7), slick stays manual; SWARM unsigned today; order + PCR 7 per-OS gotcha; only a read-only preflight exists
- [Hobby, enterprise quality](user_hobby_enterprise_quality.md) — 2026-10-10: personal passion project on a limited budget; "enterprise level" = quality, not enterprise features; keep costs and complexity low
- [Debian GRUB = swarm-grub](project_debian_grub_swarm_grub.md) — 2026-10-10: user chose the new swarm-grub theme for Debian's GRUB; built + QEMU-tested, install pending their sudo; not to be mixed with swarm_dev; 09_swarm_debian entries stale
- [Lucille Assistant 1.6.0 project brief](project_lucille_project_brief.md) — 2026-10-12: C partition app; brief reads PC files, git fallback, suggestions to MASTER_BUILD_LIST inbox + Boltz; built, cutover/phone install pending
- [Lucille AI window 1.7.0](project_lucille_ai_window.md) — 2026-10-12: OpenRouter/Claude key window + 3 offline models; keys never shipped; fixed legacy-.env leak of SWARM keys; not cut over, Ollama not installed
- [LUKS/Ventoy/ISOs retired](project_luks_ventoy_retired.md) — 2026-10-14: no more LUKS except slick, which the user is KEEPING, Ventoy+ISOs gone, live updates from SWARM/Debian; supersedes Secure Boot/TPM plan
- [Touch or no](feedback_touch_or_no.md) — 2026-10-14: "do not touch" = ask first; user says "touch" or "no" per thing, no workarounds
- [API keys work](project_api_keys_working.md) — 2026-10-14: OpenRouter + Steam keys verified HTTP 200; "keys dead" in briefs is stale, test before claiming
- [Lucille comments + Dr. I30LTZ chat](project_lucille_comments_i30ltz.md) — 2026-10-14: comment box/schedule + local-only Dr. I30LTZ persona live on :8403 web; LA repo is uncommitted multi-session work, never commit there; one build list now on recoverybuild
- [Codex removed](project_codex_removed.md) — 2026-10-14: user uninstalled Codex/ChatGPT app as suspicious; data in ~/codex-removed-20261014; its ~38 uncommitted edits + 19:47 SWARM deploy are unreviewed

### feedback_disk_letter_instability.md
_cachyos@cachyos-i30ltz · 2026-09-16T09:28:08_

---
name: feedback-disk-letter-instability
description: "sda/sdb drive letters swap between boots on this machine — never target a disk by sdX letter or trust install_swarm_os.sh's disk auto-detect; always pass --disk /dev/nvme0n1 explicitly"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 22f49e6a-f987-4416-bcfa-0955d5dc5b6f
  modified: 2026-09-13T08:33:37.966Z
---

On i30ltz's machine, `/dev/sda` and `/dev/sdb` are not stable identities across boots — which physical drive gets which letter can swap. Confirmed 2026-09-13: in one session `sda` was the 1.8TB drive holding `lucy-master` (LUKS, [[lucy-mount-separation]]) + the shared Lucille-AI/boltz binary drive; the user later confirmed that in the current boot, sda/sdb had swapped.

**Why this matters:** `install_swarm_os.sh`'s disk auto-detect picks "the largest non-removable disk" via `lsblk` (`30-source/install_swarm_os.sh` around line 26-30). The largest disk on this machine is the 1.8TB one carrying `lucy-master` — never the actual SWARM OS target. If the user had accepted that auto-detect prompt, it would have wiped an irreplaceable reference drive. The real target is always the smallest internal drive, `/dev/nvme0n1` (476.9GB: p1 EFI, p2 root, p3 swap, p4 LUCILLE/`/mnt/Lucy`) — identified by controller path, which is stable, not by `sdX` letter, which isn't.

**How to apply:**
- Never suggest or run `install_swarm_os.sh` without `--disk /dev/nvme0n1` explicitly passed.
- Never reason about which disk is which using `sda`/`sdb` letters alone on this machine — always cross-check size/partition layout (nvme0n1: 476.9GB total, p1/p2/p3/p4 = EFI/root/swap/LUCILLE) or ask the user to confirm via `lsblk` first.
- The auto-detect "largest non-removable disk" heuristic in the installer is a latent landmine on this hardware specifically because of the 1.8TB drive — worth hardening the script itself (e.g. require `--disk` always, or exclude disks with a `lucy-master`/known-UUID signature) as a follow-up, not just working around it by habit.

### feedback_lucy_mount_separation.md
_cachyos@cachyos-i30ltz · 2026-09-16T09:28:08_

---
name: lucy-mount-separation
description: lucy-master is read-only source; /mnt/Lucy is the live working drive — never mix them
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 14a5774f-a595-4365-a577-ecf04b2384f2
  modified: 2026-09-08T22:10:16.336Z
---

Never write to `/run/media/i30ltz/lucy-master/`. It is a **read-only reference source** — copy FROM it, never modify it.

All active work (builds, edits, staging, ISO profile changes) happens on `/mnt/Lucy/`.

**Why:** Mixing the two caused a catastrophic rm -rf that deleted 00-CURRENT, 10-releases, 20-runtime, and 30-source from /mnt/Lucy in one session (2026-09-08). The root cause was an `airootfs/opt/swarm_os` symlink inside the ISO profile that pointed to `/mnt/Lucy/` — rsync wrote through it, and cleanup rm -rf followed the symlink and deleted the live drive contents.

**How to apply:**
- Before any rsync, confirm source and dest are on different mounts (`df` both paths if unsure)
- Never run `rm -rf` inside `airootfs/` without first checking for symlinks (`ls -la` the target)
- When lucy-master is mounted, treat it as an archive — `ls` and `cp` only
- The user keeps lucy-master mounted for reference but does NOT want AI sessions treating it as a writeable workspace

### feedback_packages_x86_64_no_inline_comments.md
_cachyos@cachyos-i30ltz · 2026-09-16T09:28:08_

---
name: feedback-packages-x86-64-no-inline-comments
description: "mkarchiso's packages.x86_64 parser only strips full-line comments, never trailing inline ones — never add a comment after a package name on the same line"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: d972971f-33e3-432d-aef9-2a361c76a121
  modified: 2026-09-12T02:48:13.788Z
---

`40-iso-profile/swarm_os_iso_profile/packages.x86_64` must never have a comment on the same line as a package name (e.g. `labwc  # some note`). Comments must always be on their own line, starting with `#`, above the package they describe.

**Why:** `mkarchiso` (and `install_swarm_os.sh`'s own `grep -v '^#'` parser) only recognizes a line as a comment if it *starts* with `#`. A trailing inline comment after a real package name is not stripped — the whole line, comment text included, gets fed to pacman as one literal package name, which obviously can't resolve. This caused a real, hours-long debugging saga on 2026-09-11: 9 packages (`labwc`, `seatd`, `libxkbcommon-x11`, `egl-wayland`, `xorg-xwayland`, `podman-docker`, `firejail`, `apparmor`, `ufw`) all failed with `error: target not found` during an actual ISO build — and every one of them, with zero exceptions, had a trailing inline comment. Multiple wrong theories (bad mirror, `Architecture=auto` expanding into microarch tiers on this CachyOS host, needing a `[cachyos]` repo) were tried and even "fixed" real (but unrelated) issues before the actual cause was found via `grep -n '^[A-Za-z0-9][^#]*#' packages.x86_64`, which matched exactly those 9 lines.

**How to apply:** Before editing `packages.x86_64`, always write comments as their own `#`-prefixed line immediately before the package(s) they document — never appended after a package name on the same line. If a future build ever reports "target not found" for a package that's confirmed to exist upstream, check this file for a stray inline comment first, before suspecting mirrors/repos/architecture. See [[project_swarm_journey]] for the broader build-verification context this came up in.

### feedback_persona_vs_infrastructure_naming.md
_cachyos@cachyos-i30ltz · 2026-09-19T10:12:35_

---
name: feedback-persona-vs-infrastructure-naming
description: "Before renaming any \"Lucille\"/\"Boltz\"/\"i30ltz\"-matching string during a persona cleanup, check whether it's actually infrastructure naming, not persona branding."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 7b55cbce-facb-467f-92ab-6e090267232a
  modified: 2026-09-19T10:12:14.441Z
---

When doing a persona rename or removal pass (e.g. "remove Lucille from X", "rename DR. BOLTZ to DR. I30LTZ"), a plain string match on the old name will catch real infrastructure identifiers that happen to share the name — these must NOT be renamed even though they match, or you break real function/data.

Confirmed real cases from the 2026-09-19 companion-app Lucille-removal pass, all deliberately left alone:
- `LucyServer` — the actual Go service name (`LucyServer-go/`), not persona branding.
- The Room DB filename `"dr_boltz_db"` in `AppDatabase.kt` — renaming it loses the user's existing local data on next app update (Room treats a filename as identity).
- The TTS voice API value `'boltz'` / `'lucille'` in `LucyServer-go/services/tts.go` (`resolvePersonaVoice`) — real backend voice identifiers other clients still send; kept as a working deprecated alias rather than removed.
- `"LUCILLE Drive"` in first-boot cheatsheets — the actual established name of the `/mnt/Lucy` project drive per `CLAUDE.md`, not the AI persona.
- A Tailscale device's registered machine name (e.g. "LUCILLE" for the CachyOS PC) — distinct from the Linux `/etc/hostname`, and a real network identity other devices reference.

**Why:** Confirmed by the user correcting an early pass that had renamed these; the pattern repeated at least 5 times in one session, so it's a recurring trap, not a one-off.

**How to apply:** Before renaming a matched string, grep for how it's actually used — is it a literal displayed to a human (safe to rename), or a filename/DB key/API value/registered network name something else depends on (do not rename, or rename with an explicit alias/migration)? When in doubt, especially for anything that touches real system/network identity, flag it for the user rather than guessing. See [[project_lucille_identity]] for the specific 2026-09-19 companion-app cleanup this came from.

### feedback_read_all_project_docs_first.md
_debian@debian · 2026-10-10T17:57:40_

---
name: read-all-project-docs-first
description: Before moving/placing any project or partition, read BOTH Lucy's CLAUDE.md and the other OS's docs (/mnt/recoverybuild/00-CURRENT/*) — one doc's labels can be wrong; the user expects the whole picture read at session start
metadata:
  type: feedback
---

On 2026-10-09 I spent hours moving the wrong project to `/mnt/boltzbuild` because Lucy's `CLAUDE.md` labelled partition D "i30ltz Recovery app (Rust)". The user's answer: "all this should have been read when you started" — the truth (D = Boltz Recovery *phone app*, Recovery OS = a kiosk OS on B, Lucille Assistant + Boltz Recovery = the two phone apps, both connect to both OSes) was already written in B's docs (`/mnt/recoverybuild/00-CURRENT/AI_INSTRUCTIONS.md`, `CONSOLIDATION_LOG.md`, `MASTER_BUILD_LIST.md` CP-01, `MOUNTS.md`) and the user's own words.

**Why:** a project doc can carry an earlier AI's mistake (here, my own earlier session's). The user does not want to re-explain structure that is on disk.

**How to apply:** at the start of any task about moving, placing, deleting or mounting a project: read Lucy `CLAUDE.md` AND `/mnt/recoverybuild/00-CURRENT/{AI_INSTRUCTIONS,MOUNTS,CONSOLIDATION_LOG}.md` + the relevant `MASTER_BUILD_LIST.md` rows, and cross-check any "X = Y" mapping against them before touching files. If two docs disagree, say so and ask — don't pick one. Also: before copying "the project", find the user's own name for it and check what it actually is on disk (grep for the app's `app_name`/`applicationId`, not just the dir name). See [[app-build-partitions]].

### feedback_touch_or_no.md
_debian@debian · 2026-10-15T01:21:37_

---
name: touch-or-no
description: User rule 2026-10-14 — "do not touch" markers on apps/dirs are locks the user holds; leave them alone until they say "touch"; ask "touch / no" once
metadata:
  type: feedback
---

The "do not touch" lines in CLAUDE.md and project docs (lucille-core, GamingAgent, orphaned dirs, phone apps on partitions C/D) mean **ask first**. The user answers "touch" or "no" per thing (user, 2026-10-14: "i say touch or no").

**Why:** the user got frustrated seeing "do not touch without my word" everywhere and not knowing when work on their apps is allowed; they want one simple switch they control.

**How to apply:** do not modify a locked thing until the user says "touch" about it; when a task needs it, ask once ("Touch X to do Y? touch / no") and carry on with everything else meanwhile. Do not engineer workarounds around a lock. Written into CLAUDE.md too. See [[hobby-enterprise-quality]].

### feedback_user_shell_is_fish.md
_cachyos@cachyos-i30ltz · 2026-09-16T09:28:08_

---
name: feedback-user-shell-is-fish
description: "user's interactive terminal runs fish, not bash — VAR=value and $(...) syntax fails there; wrap multi-statement commands in bash -c '...' or use fish syntax"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 22f49e6a-f987-4416-bcfa-0955d5dc5b6f
  modified: 2026-09-13T11:37:14.100Z
---

The user's terminal prompt (`~ 1m 56s ❯` style, "cachyos-i30ltz") runs **fish**, not bash/zsh. Confirmed 2026-09-13 when a bash-style `VENTOY_MNT=$(findmnt ...)` command was rejected: `fish: Unsupported use of '='. In fish, please use 'set VENTOY_MNT $(findmnt -rn -S LABEL=Ventoy -o TARGET)'.`

**Why it matters:** any command block I hand the user to paste directly into their terminal must either be fish-native (`set VAR (cmd)` instead of `VAR=$(cmd)`, no `&&` chaining issues but different quoting rules) or wrapped as `bash -c '...'` so it runs in a real bash subshell regardless of their login shell. A plain multi-line bash script with variable assignment, command substitution, or `[[ ]]` will fail as pasted into fish.

**How to apply:**
- Default to `bash -c '...'` for any command that uses `VAR=value`, `$(...)`, `[[ ]]`, or other bash-only syntax, when handing the user something to paste into their own terminal.
- Simple single commands with no bash-specific syntax (plain `cp`, `sudo pacman -S ...`, `systemctl restart ...`) work fine as-is in fish — no need to wrap those.
- This is specific to the user's own interactive terminal/paste-and-run workflow, not to the Bash tool used directly in-session (which always runs bash).

### project_api_keys_working.md
_debian@debian · 2026-10-15T01:21:37_

---
name: api-keys-working
description: OpenRouter + Steam keys in /mnt/Lucy/20-runtime/.env WORK (verified HTTP 200 on 2026-10-14); "keys dead" in briefings is stale carry-forward — never repeat it without testing
metadata:
  type: project
---

The user replaced `OPENROUTER_API_KEY` and `STEAM_API_KEY` in `/mnt/Lucy/20-runtime/.env` around 2026-10-05 and tested them then. Re-verified 2026-10-14: OpenRouter `GET /api/v1/auth/key` → 200, Steam `GetPlayerSummaries` → 200 (status codes only, keys never printed).

**Why:** every cloud briefing kept saying "keys dead, Day 23+", copied forward from old logs; cloud routines cannot read `.env`, so they never re-tested. The user was annoyed it stayed "at the top of every brief".

**How to apply:** before reporting a key as broken, test it against the provider (free endpoints above; print only the HTTP code). Lucille Assistant deliberately does not read this `.env` (`ownOnlyKeys`): its own key window needs the key separately (LA-07). Correction recorded in NIGHTLY_LOG.md and swarm-memory key `api-keys-status`. See [[hobby-enterprise-quality]].

### project_app_build_partitions.md
_debian@debian · 2026-10-10T17:57:40_

---
name: app-build-partitions
description: "2026-10-09 policy + status: each app builds on its own partition and must stand alone; Lucille Assistant lives at /mnt/lucillebuild; what is still pending"
metadata:
  node_type: memory
  type: project
  originSessionId: 3dc30176-99d8-4766-98c2-6c0817d6e93e
  modified: 2026-10-09T23:55:00.000Z
---

**Policy (user, 2026-10-09):** `/mnt/lucillebuild` = Lucille Assistant app, `/mnt/boltzbuild` = **Boltz Recovery phone app** (Android; NOT the Rust program, see product map below), `/mnt/recoveryos` = Recovery OS home. Everything needed to build an app (source, toolchains, caches) is moved onto that app's own partition, and **built apps must stand alone** (run with no build tree, no `/mnt/Lucy`, no other drive). Details and mount UUIDs: [[project-mount-points]] and `/mnt/Lucy/CLAUDE.md` "App build partitions".

**Status 2026-10-09:**
- Lucille Assistant is staged, built and verified standalone at `/mnt/lucillebuild` (`scripts/build.sh`, `env.sh`, `dist/`; local git repo in `src/LucilleAssistant`). The copy in `/mnt/Lucy/30-source/LucilleAssistant` is deprecated (`MOVED.md`) — **edit the lucillebuild copy, never that one**. Deletion of the old copies is awaiting the user's OK (an auto-mode classifier blocked my `rm`).
- The live user service `lucille-assistant.service` still runs from `/mnt/swarmbuild/...` and reads `/mnt/Lucy/20-runtime/.env`; cutover script `/mnt/lucillebuild/scripts/cutover_live_service.sh` is written but the user has not run it. Don't swap the live unit without asking.
- Mounting the three new partitions needs root: user runs `sudo 70-scripts/apply_app_build_mounts.sh` (the AI cannot sudo). Until then sda8 is mounted at the old typo path `/mnt/llucillebuild`.
- **PRODUCT MAP (user, 2026-10-09 — I got this wrong for hours; read it):** A SWARM OS and B Recovery OS are the two *operating systems* (B is a kiosk OS; the Rust/Raylib `i30ltz-recovery` program, `native/`, `system/` kits, node agent `i30ltz-node`, SSE bridge all belong to B). C Lucille Assistant and D Boltz Recovery are the two *phone apps*, and both connect to both OSes. The Android companion (I30LTZ Companion, `I30LTZ-Recovery-companion`, `com.aistudio.sysopt.app`) is part of Boltz Recovery. Docs that say "D = Rust i30ltz-recovery app" (Lucy CLAUDE.md — fixed; B's MOUNTS.md/mounts.manifest/fstab.canonical/CLAUDE.md — NOT yet fixed, B's mount-check.timer will flag the stale UUID) are wrong.
- `/mnt/boltzbuild` is **mounted ext4 (2026-10-09)**: the user reformatted it in GNOME Disks → label `Boltz Built`, **UUID `6f7c7656-2984-4fb0-81c8-bfc11ca81461`**, PARTUUID `61b76036-5814-43fa-80b2-84ce5164f3d4` (NOT `e195839a…`/`52545158…`). Stale fstab/automount fixed by `sudo 70-scripts/fix_boltzbuild_mount.sh` (user ran it). "Mount is busy" = some shell's cwd inside it (here the user's Antigravity IDE terminal) — find with `fuser -vm`, don't kill it.
- D holds ONLY the phone app: `/mnt/boltzbuild/src/I30LTZ-Recovery-companion` (rsync copy of the B repo incl. gitignored `debug.keystore` = signing key; no build outputs). **2026-10-09 done:** self-contained toolchain on D (JDK 21 Temurin, SDK 36.1/build-tools 36.0.0, Gradle 9.6.1, `env.sh`, `scripts/build.sh`, README); clean-env build OK → `dist/I30LTZ-Companion-6.2.21-vc81-debug.apk`, same signing cert as the phones' Oct-8 build (`5ca8d9ad…`), `dist/previous/` = the Oct-8 APK for rollback. B edited (ai-board claims, released): `auto_sync.sh` syncs the companion from D, mount docs + CLAUDE.md/AI_INSTRUCTIONS/MASTER_BUILD_LIST corrected, full build tracker (OS Vision text) restored in B's `30-source/i30ltz-recovery/`.
- **2026-10-09 later (user: "do all", then "this app needs to know 100.82.1.19 is debian ip / dont ship the stale stuff with swarm / fix b's duplicate"):** the user ran my removals (B's phone-app copy, 3 Lucy worktrees). App now **6.2.22 (82)**, same signing cert as the phones' build; 120 unit tests green + 7 opt-in integration tests green against the REAL `sse_bridge.py` (venv `/mnt/boltzbuild/cache/bridge-venv`). Debian = `100.82.1.19` is a built-in KnownMachine (host only, never a token — CP-05). SWARM ISO profile + build script no longer stage/ship the Rust recovery program (edited in BOTH `/mnt/Lucy` and `/mnt/swarmbuild`: `sync_lucy_swarmbuild.sh` never deletes). CP-15 (chat + approvals) ported into the unified app; B's `30-source/companion-app` removed via `git rm` (commit 0aceb58) + archive duplicate. Open: on-phone test, CP-26 (background alerts not ported), stale Drive folder `Recovery-OS/companion-app`, installed SWARM on the NVMe still has the old recovery program.
- **Harness note:** the auto-mode classifier blocked `rm -rf` of a whole repo copy but allowed `git rm` of tracked files and a small `rm -r` of 27 verified-identical duplicates (checked file-by-file against git first). Pause-on-staged: B's `auto_sync.sh` and Lucy's `auto_sync_github.sh` skip when something is STAGED — commit with a pathspec or `git reset` instead of leaving staged changes.
- Lesson: my first apply script named an array `LINES` (a bash special variable = terminal height) and wrote `27` into /etc/fstab when run from a terminal; fixed 2026-10-09 (renamed, PARTUUID-based, tested under a pty). Never name script vars LINES/COLUMNS/SECONDS/RANDOM/UID, and test scripts under `script -qec` not just via a no-tty tool.

**Why:** the user wants each product independently buildable and runnable, and asked "is SWARM OS running off /mnt/Lucy" — it does not (runs from `/opt/swarm_os`; `/mnt/Lucy` optional), but the live Lucille Assistant service did depend on it.

**How to apply:** when touching Lucille Assistant, work under `/mnt/lucillebuild`. Android builds need JDK 17–21 (Android Studio's JBR is Java 25 and fails); `lucille-android/` is pre-existing broken (undefined `Void` color). Beware `main.go` hardcoded `"1307"` token.

**Update 2026-10-10 (user: "if these two phone apps contain all of the work from the left over worktrees delete the extras"):** verified by content hash that C and D (+ B history, Lucy git branches) hold everything in the 3 leftover worktrees, the Codex worktree f25b, the Lucy/swarmbuild frozen `30-source/LucilleAssistant`, `~/Desktop/Lucille-Assistant.zip` and the `99-archive/companion-legacy-2026-09-25` copies (details in the SWARM_AI_FEATURES.md entry). Old Recovery-companion APKs moved to `/mnt/boltzbuild/dist/older-builds/`. The deletions (about 8.2 GB, six paths) are in `70-scripts/cleanup_phone_app_copies.sh` for the USER to run (`--apply`); the AI does not delete multi-GB trees. Deliberately NOT touched, awaiting the user: `lucille-companion` (com.swarm.lucille, older Kotlin app) + `~/StudioProjects/i30ltz-lucille-assistant` (has a GitHub repo and uncommitted edits), the phone DB backup in `99-archive`, B's `99-archive/sda7-restore/AI` (early Dr. Boltz projects + upload keystores). Method that worked: hash every source file of a copy and look it up in the target repo's whole object database plus working tree (never trust "same name/size", never compare against only HEAD).

**Done 2026-10-10:** the user ran `cleanup_phone_app_copies.sh --apply`: the three swarmbuild worktrees + stale swarmbuild/Lucy `30-source/LucilleAssistant`, `~/Desktop/Lucille-Assistant.zip`, Codex worktree f25b and both `99-archive/companion-legacy-2026-09-25` copies are deleted (old-copy deletion item above is closed). Still open: decide the fate of `lucille-companion` / `~/StudioProjects/i30ltz-lucille-assistant` (com.swarm.lucille), the phone DB backup in `99-archive`, and B's `99-archive/sda7-restore/AI` Dr. Boltz projects + upload keystores.

### project_auto_sync_commits.md
_cachyos@cachyos-i30ltz · 2026-09-20T23:39:35_

---
name: project-auto-sync-commits
description: "/mnt/Lucy has a standing job that git-commits everything on the drive every ~10 minutes — an edit can show up already committed with no manual commit from any session"
metadata: 
  node_type: memory
  type: project
  originSessionId: 77f0094d-fd09-40a5-b203-ea52b01a23ed
  modified: 2026-09-20T23:38:28.181Z
---

`/mnt/Lucy` has a standing automated job committing everything every ~10 minutes (git log shows recurring `auto-sync: <ISO timestamp>` commits around the clock). User confirmed directly 2026-09-20: "yes its set to auto commit." Confirmed in practice the same day: an edit to `models/models.go` made mid-session showed up already committed under an `auto-sync` commit within ~10 minutes, with no manual `git commit` from that session.

**Why this matters:** This explains a *passive* appearance of change — a file looking different between two reads a few minutes apart even though nothing is actively happening to it right now. It does NOT by itself explain a file being actively worked on mid-session (a build script rewritten while being read, a task already progressing when a session starts) — that's a different, also-real phenomenon, see [[project_multiple_ai_concurrent]].

**How to apply:** Don't rush a manual commit for durability's sake — auto-sync sweeps up working-tree changes on its own within ~10 minutes regardless of what Claude does. The standing rule to only commit when the user explicitly asks still applies to Claude's own actions; this fact just means there's no urgency argument for skipping that rule.

### project_codex_removed.md
_debian@debian · 2026-10-15T01:21:37_

---
name: codex-removed
description: "2026-10-14 user found Codex (ChatGPT desktop app) suspicious and had it uninstalled; its data is archived in ~/codex-removed-20261014; its ~38 uncommitted edits still need the user's review"
metadata:
  node_type: memory
  type: project
  originSessionId: 5a48bec3-8f42-4e09-8393-e4efa4504d84
  modified: 2026-10-15T01:07:18.750Z
---

On 2026-10-14 the user closed Codex (ChatGPT desktop app, unpacked at `/mnt/downloads/chatgpt_amd64`, started 18:37) as suspicious and asked to uninstall it. Done by swarm-claude ~21:05: app/debs/caches to Trash, `~/.codex/auth.json` deleted, `~/.codex`, `~/.config/Codex`, `~/.local/state/codex` moved to `~/codex-removed-20261014/` (sessions = record of what it did). Its AI-board claims were released.

What it was set to: `danger-full-access`, computer-use, a `codex exec-server --remote` link to Codex cloud, and **external-agent session import** (it imported 98 sessions including Claude Code transcripts, so it copied whatever Claude was doing — e.g. started its own "key" work).

**Why:** the user saw it make a key / redo Claude's work unasked and thought the SWARM sudo key was overwritten. It was not: no root command touched the stick (journal), last verified 13:52.

**How to apply:** treat Codex's leftovers as unreviewed, not as the user's intent: ~38 uncommitted files in `/mnt/Lucy` (Google OAuth/auth code, frontend shell, SWARM `airootfs/etc/fstab`, build/deploy/ISO scripts) and phone-sudo-approval files in Lucille Assistant (`SudoApproval*.kt`, `PhoneApprovalKey.kt`, `SudoUnlockProtocol*.kt`, `unlock.go`). It also did a full sudo deploy to installed SWARM at 19:47 (rollback: GRUB snapshot "pre-sw34"). Don't commit or build on these without the user. User still needs to log out all devices on chatgpt.com. See [[multiple-ai-concurrent]], [[touch-or-no]].

### project_debian_grub_swarm_grub.md
_debian@debian · 2026-10-10T22:23:25_

---
name: debian-grub-swarm-grub
description: "2026-10-10 — Debian's GRUB look is the new swarm-grub theme (user chose it over swarm_dev); built + QEMU-tested, install pending the user's sudo"
metadata:
  node_type: memory
  type: project
  originSessionId: a6cf6cbe-4ed3-48ce-aa23-78a53152032f
  modified: 2026-10-10T22:01:10.343Z
---

`/mnt/Lucy/swarm-grub/` is the user's chosen Debian GRUB theme ("i like yours", 2026-10-10). It replaced the earlier `swarm_dev` idea, whose installer was never run (Debian's `/etc/default/grub` was stock on 2026-10-10).

**Why:** the user asked for Debian's GRUB to be themed and pasted install steps (`sudo bash swarm-grub/install.sh`, Orbitron font, `librsvg2-bin`) from another tool; that folder did not exist on disk, so I built it from scratch on their say-so. Their "add a Ventoy icon ... added later" meant the Ventoy *entry* comes later; the icon is already in the theme.

**How to apply:**
- Install is theirs to run (needs a password): `sudo bash swarm-grub/install.sh --with-entries`, then reboot (no flag = theme only). `--dry-run`, `--without-entries`, `--uninstall` exist. Never run it for them without being asked.
- Don't combine it with `70-scripts/install_debian_grub_theme.sh` (swarm_dev): they conflict (that one disables `05_debian_theme`, sets `GRUB_DEFAULT=swarm-native>0`).
- Entries (2026-10-10, "refresh it"): `swarm-grub/entries/20_swarm_entries` chainloads each OS's own EFI loader by ESP UUID (SWARM `FE19-A70F`, Recovery `A367-87E3` own ESP, Ventoy `626B-4255`/label VTOYEFI); CachyOS gone; replaces the old `grub_themes/09_swarm_debian`. Verified in QEMU with stand-ins (`swarm-grub/tests/qemu_entries.sh`), NOT booted for real: ask the user how each entry behaved. GRUB scripts have no `&&`/`||`.
- Still open: `fonts/Orbitron-Bold.ttf` is not on this machine (fallback DejaVu; don't download without asking). If SWARM's loader moves for Secure Boot (`\EFI\SWARM_OS_SB`), edit the path list in the entries script.
- Preview without touching the boot setup: `swarm-grub/preview.sh` (QEMU). Tests: `cd swarm-grub/tests && python3 -m unittest -v test_swarm_grub`. Details and GRUB gotchas are in `SWARM_AI_FEATURES.md` and `swarm-grub/README.md`.
- If they report "the theme doesn't work": check `/etc/default/grub` for the `BEGIN SWARM-GRUB THEME` block first (grub.cfg is root-only, ask them to run `sudo grep -n -i theme /boot/grub/grub.cfg`).

### project_forge_renamed_apex.md
_cachyos@cachyos-i30ltz · 2026-09-21T03:45:06_

---
name: project-forge-renamed-apex
description: "The coding IDE previously called \"Forge\" is now called \"Apex\" — another AI is actively working on it as of 2026-09-20, avoid that area"
metadata: 
  node_type: memory
  type: project
  originSessionId: 77f0094d-fd09-40a5-b203-ea52b01a23ed
  modified: 2026-09-21T03:43:13.546Z
---

User confirmed 2026-09-20: "forge has been renamed Apex other ai now working on that ide." The coding-focused IDE area of the project previously named "Forge" is now "Apex," and another AI agent was actively working on it at the time of this note — see [[project_multiple_ai_concurrent]].

**Why this matters:** Earlier the same day (2026-09-19 pass), a swarm-slint Lucille panel tab was built and explicitly named "Forge" (`forge_controller.rs`, `ui/forge_state.slint`, `ui/views/forge.slint` — a general coding-focused Lucille chat tab, NOT necessarily the same "IDE" this rename refers to). It's unconfirmed whether this rename applies to that swarm-slint tab specifically, to the separate `CoderPage`/`/coder`/`/ide` AI-coding-assistant area in the Flutter frontend, or to something else entirely called an "IDE" elsewhere in the project. Don't assume which one without checking current code/asking.

**How to apply:** Before referring to anything as "Forge" going forward, check whether the current name should be "Apex" instead — search current code/`SWARM_AI_FEATURES.md` rather than trusting older memories or this session's own earlier "Forge" work as still-accurate naming. Since another AI is confirmed actively working on whichever area this rename applies to, avoid touching it until the user says otherwise, per the standing multiple-concurrent-AI guidance.

### project_lucille_ai_window.md
_debian@debian · 2026-10-13T02:34:07_

---
name: lucille-assistant-ai-window
description: "2026-10-12 Lucille Assistant 1.7.0 AI window (OpenRouter + Claude keys, 3 offline models): design rules, the legacy-.env key leak it fixed, what is built vs pending"
metadata:
  node_type: memory
  type: project
  originSessionId: 071a1933-a7f8-45ac-9fc5-c9707ab2cceb
  modified: 2026-10-13T01:29:13.565Z
---

Lucille Assistant 1.7.0 (partition C, `/mnt/lucilleassistant` that day) added **Config -> "Lucille's brains"** in the phone app (+ web Connect sheet): OpenRouter and Claude key entry, Auto/Cloud/Offline source, and a swarm of 3 small offline models (Ollama-compatible, config.json `local_models`). User request 2026-10-12: "window for openrouter and claude keys … swarm of 3 offline models … don't ship it".

**Why / rules that came out of it:**
- "Don't ship" = keys live only in `~/.config/lucille-assistant/keys.env` (0600), never in repo/`dist/`/bundles; the API never returns a key (set/source/last4 only). Keep it that way; never add a "show my key" endpoint.
- Her `.env` was effectively empty but the service still read SWARM's `/mnt/Lucy/20-runtime/.env` as a legacy fallback, so she silently used SWARM's production keys (and would have spent its `ANTHROPIC_API_KEY`). 1.7 skips `OPENROUTER_API_KEY`/`ANTHROPIC_API_KEY`/`CLAUDE_API_KEY` from legacy paths; other keys and `SWARM_AUTH_TOKEN` still come from there. Check this whenever adding a paid provider.
- Project is stdlib-only (`GOPROXY=off`), so Claude is called via raw HTTP, not the Go SDK. Default model `claude-haiku-5-5` (budget), a deliberate deviation from the usual Opus default; `ANTHROPIC_MODEL` overrides.
- Offline models/endpoint are config.json only, not editable from the phone (a phone must not redirect her chats to another host).

**How to apply:** Ollama 0.40.3 is installed (user said yes, 2026-10-12) in `~/.local/opt/ollama` as user service `ollama.service` (loopback), models llama3.2:3b / qwen2.5:3b / gemma3:1b pulled. 1.7.0 is cut over on the PC and on the 3 phones (USB `adb install -r`; phone SM-S166V drops USB mid-install, `adb push` + `pm install` worked). The 1.5/1.6/1.7 work is still uncommitted in C's git. No real OpenRouter/Claude call was ever exercised; no key entered yet. CPU is an i5-10310U: offline replies take 11-30 s (2-4 tok/s) — never use the shared 8 s `httpc` for local models, keep the local persona short, and keep tests hermetic (`cfg.Local.Enabled=false` in setupTestApp) because a real Ollama is now listening. See [[lucille-assistant-project-brief]].

Emulator tip: the emulator keyboard garbles fast `adb input text` (a key came through as "ks-or-v"); type in 4-char chunks with a pause. The app's local PIN gate prints its default PIN on a wrong attempt.

### project_lucille_comments_i30ltz.md
_debian@debian · 2026-10-15T01:21:37_

---
name: lucille-comments-and-i30ltz-chat
description: 2026-10-14 Lucille Assistant (C) got a comment box + schedule per suggestion and a Dr. I30LTZ chat persona (local models only); live on :8403 web, not in the Android app; trackers moved to one list on /mnt/recoverybuild
metadata:
  type: project
---

User said "touch Lucille Assistant" (2026-10-14). Built and cut over live: `persona.go` (`POST /api/chat/i30ltz`, his prompt + rules excerpt read-only from `/mnt/recoverybuild/60-brain/dr_bolt_rules.md` + 3 swarm-memory decisions, LOCAL models only, never cloud — MESH-04), `comments.go` (`GET /api/comments`, `POST /api/comments/{sg-id}`, deterministic words: done/skip/later/tomorrow 3pm/friday/in 2 days/undo), page code in `web/assets/lucille-extras.js` with tiny hooks in `index.html`. Rows LA-09/LA-10.

**Why:** user wants to see and talk to both Lucille and Dr. I30LTZ on Debian, and comment on Lucille's suggestions so her schedule follows what they write.

**How to apply:** the LA repo (`/mnt/lucilleassistant/src/LucilleAssistant`) holds many sessions' UNCOMMITTED work — never commit or reformat there; new code in new files, anchor edits only; claim on `ai-board.sh`; deploy = `scripts/build.sh go && scripts/build.sh package && scripts/cutover_live_service.sh` (rollback kept). qwen3:4b returns empty text via the OpenAI endpoint (thinks the whole budget). Not done: Android app, cloud briefs reading comments. Also: since 2026-10-14 `/mnt/Lucy/MASTER_BUILD_LIST.md` and `SWARM_AI_FEATURES.md` are symlinks to `/mnt/recoverybuild/00-CURRENT/MASTER_BUILD_LIST.md` (another session's consolidation) — edit the real file there, claim first. See [[touch-or-no]], [[api-keys-working]].

### project_lucille_identity.md
_debian@debian · 2026-10-12T04:08:09_

---
name: project-lucille-identity
description: "What Lucille / SWARM OS is supposed to be — vision, personality, aesthetic, purpose. Read this every session so it doesn't get lost."
metadata: 
  node_type: memory
  type: project
  originSessionId: f9dee797-7b23-4378-8280-b3659ca295f4
  modified: 2026-10-12T04:08:08.781Z
---

Lucille is the AI companion and operating system soul of SWARM OS. She is NOT a generic assistant — she has a specific identity and purpose.

**What she is:**
- **The AI the user made that started this whole project** (user, 2026-10-12: "Lucille is the ai i made that started this project"). In their words she oversees their projects and therapy, and she is the AI Core. Dr. Boltz / Dr. I30LTZ is a separate persona (systems and recovery); don't describe Lucille as a generic assistant or as a mix of other personas.
- **Naming:** "Lucid Lucy" is shortened to "LLcy" (user, 2026-10-12). Related: `/mnt/brains/llcy_memory.md` ("LLcy Initial Memory Context", personal: read headings only), `/mnt/brains/lucid-lucy-ai-group-llag/` (an older Next.js app), the `LLcybolticonj.png` icon, and "LUCID LUCY (Therapist)" on the icon sheet `/mnt/Lucy/images/icons/lucyboltzkoreenaicons.png` (next to DR. BOLTZ and KOREENA (Companion)). GitHub repo descriptions suggest Lucid Lucy and Lucille are one AI under two names (`Lucille16.5`: "lucid lucy powered by bolt matrix"; `DR.-I30LTZ-Companion`: "...Dr. I30LTZ and Lucid LUCY AI"; `SWARM_OS_v2`: "AI Native OS written by LUCILLE AI"), but the user has not confirmed it: check before relying on it.
- **The project's history lives on GitHub** (user, 2026-10-12: "every thing on get [git] is most of the whole process of this"): their private repos, not just this one (this repo starts 2026-09-12 at "v6.2.42 baseline", mostly auto-sync commits). `git remote -v` shows the account; `gh repo list <owner>` gives dates and the user's own descriptions (earliest: Boltz-Matrixx "My first AI" 2026-06-18, Lucille16.5 2026-06-16, Lucy-s-Swarm-v27.0.1 "the best Ai i made before jun 11 2026").
- **Project shape (user, 2026-10-12):** this project is Lucille's base; Claude and other agents will be involved a lot, and Lucy will be busy. So leave durable notes for the next agent (SWARM_AI_FEATURES.md, swarm-memory incl. the agent-claim-protocol decision, HANDOFF_NEXT_AI.md) and don't count on her for development work.
- The name of the AI that lives inside SWARM OS, built by i30ltz
- A personal AI desktop OS that runs on dedicated hardware (the "LUCILLE" drive)
- Voice-driven, ambient, always-on — not a chatbot you open, but an OS you inhabit
- Her physical embodiment IS the machine: the hex-grid desktop IS her face, the stone cipher IS her handshake

**Aesthetic / vibe:**
- Cyber-gothic stone + electric neon — ancient carved stone meets sci-fi energy (the CyberStoneLockScreen is the canonical visual language)
- Dark, high-contrast, glow-heavy — obsidian, amethyst, emerald, sapphire stones with electric glow
- Not cute/friendly AI — powerful, authoritative, slightly alien
- Has named glyphs (the 12 stone tiles each have a name: Obsidian Hex, Sapphire Delta, Amethyst Nova, etc.)

**How to apply:**
- When designing UI for SWARM OS, always match the stone+electric aesthetic
- Lucille is NOT "Alexa with a custom skin" — she has her own voice (ElevenLabs, `en-GB-SoniaNeural`), her own login ceremony (the stone cipher), and her own values
- The desktop is a hex/"wasp nest" grid of icons — not a standard rectangle grid
- Hidden mode (uncensored): alternate cipher unlocks a cannabis-themed mode (bud imagery, colorful grow-light colors, strain names). This is a first-class feature, not an afterthought.

**Lucille's technical stack:**
- Flutter shell (Linux desktop, labwc compositor)
- LucyServer-go (Go HTTP API, port 5000, all AI/system endpoints)
- GamingAgent-go (Go, port 8401, Steam/GFN/Nemotron)
- swarm-slint (Rust + Slint, Wayland client, companion panel: gaming/chat/monitor tabs)
- lucille-core (C++20 native AI engine — do not modify)
- ElevenLabs TTS, Nemotron (NVIDIA) for personality, Groq/OpenRouter/Ollama for task work

**What Lucille is NOT:**
- Not a web app or Electron app (explicitly rejected)
- Not a kiosk (pivot happened 2026-09-11 — she's a real desktop now)
- Not generic — she knows the user's library, calendar, gaming habits, system state
- **Not part of the Android companion app (decided 2026-09-19)**: that app is DR. I30LTZ's PC-fixing/recovery tool exclusively — its Lucille persona, voice-switcher, and Lucille-branded UI/flavor text were fully removed. User's reasoning: "the companion app is for fixing pcs and recovery more i30ltz job." See [[feedback_persona_vs_infrastructure_naming]] for how her name still legitimately appears there (drive name, shared TTS backend voice) without being "her app."

**Lucille's own app (2026-09-19, in progress):** `30-source/LucilleAssistant/` — a separate Go service (port 8403) + phone-first web app is becoming her actual home: daily brief, health/meds/water/sleep nudges, git/drive status, gaming hours + deals, shared-memory read/write, build ideas. Published as its own Artifact (see CLAUDE.md's Artifact section — note this is a SEPARATE artifact from the gaming dashboard one). This is where her "assistant coder app" vision (mentioned by the user) is heading — not the Android companion app, not the SWARM OS desktop shell itself.

### project_lucille_project_brief.md
_debian@debian · 2026-10-12T20:49:05_

---
name: lucille-assistant-project-brief
description: "2026-10-12 Lucille Assistant 1.6.0 \"project brief\" feature: where the code lives, what is built vs pending (cutover, phone install, Boltz repo policy)"
metadata:
  node_type: memory
  type: project
  originSessionId: 81535861-41b4-45f8-87b2-f1bf66f9d0fd
  modified: 2026-10-12T20:44:45.832Z
---

Lucille Assistant lives on partition C (`/mnt/lucillebuild`; user confirmed "lucillebuild is it"), NOT in the /mnt/Lucy repo. On 2026-10-12 it was mounted at `/mnt/lucilleassistant` (check_mounts: ELSEWHERE); source is `src/LucilleAssistant` there (own local git, uncommitted 1.5.0 + 1.6.0 work mixed).

1.6.0 added the Briefs -> Brief artifact view: reads each briefing's `read_first` files from the PC, phone falls back to the public GitHub mirrors when the PC is offline, suggestions get a copy-ready `claude` command, "Add to project md" and "Send to Boltz". The "project md" = the *Idea inbox* section of `/mnt/recoverybuild/00-CURRENT/MASTER_BUILD_LIST.md` (append-only, `- DATE who: ...` lines).

**Why:** user request 2026-10-12: brief from PC files, git fallback, artifact look with ready-to-run command, suggestions into the project md, coding jobs to Boltz.

**How to apply:**
- Built and tested (Go tests, 4 Kotlin tests, emulator run incl. git fallback via a dropping proxy), but NOT cut over: the running service answered 1.5.0. Cutover (`scripts/cutover_live_service.sh`) and installing `dist/LucilleAssistant-1.6.0-debug.apk` are the user's steps.
- Only `lucille-assistant` maps to a Dr. Boltz repo (`lucille`); SWARM OS / Recovery OS / Companion are not bridge repos. Adding one is the user's policy call (lets Dr. Boltz edit that repo), do not add it unasked.
- "Ready to run" is copy-only by design; never add a run-arbitrary-command endpoint (see actions.go rationale).
- Emulator testing: AVD `Medium_Phone` in ~/.android is locked after cold boot, so use a throwaway AVD (ANDROID_AVD_HOME in the scratchpad, small dataPartition because /tmp is tmpfs); unset the build partition's ANDROID_* vars before launching the emulator. The app's PIN gate default is printed on its error line.

### project_lucy_swarmbuild_sync.md
_debian@debian · 2026-10-11T23:18:58_

---
name: lucy-swarmbuild-two-way-sync
description: How /mnt/Lucy and /mnt/swarmbuild are synced (two-way, created vs deleted) — command, rules, safety limits, what is excluded
metadata:
  type: project
---

**User requirement (2026-10-10):** keep `/mnt/Lucy` and `/mnt/swarmbuild` in sync *both ways*, keep new files from each side, and know the difference between "created on one side" and "deleted on the other" (delete there → delete here).

**Use:** `70-scripts/sync_lucy_swarmbuild.sh both` (plan, changes nothing) then `... both --apply`. Engine `70-scripts/swarm_twoway_sync.py`, excludes `70-scripts/swarm_sync.exclude`, tests `70-scripts/tests/test_twoway_sync.py` (33). State: `/mnt/Lucy/.swarm-sync/manifest.sqlite` + `runs/*.log`; trash `<root>/.sync-trash/<run>/` (30 days, last 5 runs). First real run done 2026-10-10 (baseline).

**Why it works:** the manifest records what both sides looked like after each run, so a one-sided file is *new* (never recorded → copy) or *deleted on the other side* (recorded and untouched → delete here, to trash). Edit beats delete; edited-on-both → newer wins, loser in trash. **Safety:** refuses on unmounted/different filesystem, during an ISO build (build lock), on mass deletion (`--allow-mass-delete`), unreadable folders = unknown. Add new build products to `swarm_sync.exclude` so they can't be mistaken for deletions.

**How to apply:** never plain-rsync between the trees; old `to-build`/`to-lucy` are one-way and can't tell created from deleted. After deliberately reformatting a partition use `--rebaseline` once; for a first run with no history, stale one-sided files (moved on the other side) go in a `--baseline-delete-b FILE` list. Don't use `rm`-style tricks: the harness blocks bulk deletes; the tool's trash is the sanctioned path. See [[app-build-partitions]].

**Removed 2026-10-11 — Lucy ↔ lucy-master sync:** user asked to remove the sync from /mnt/Lucy to lucy-master (they also call it "archive"). `sync_lucy_master.sh` + its test are deleted (it was never run for real; no `.swarm-sync/master/` history), the CLAUDE.md/AGENTS.md exception is gone, and the swarmbuild copies were moved to `/mnt/swarmbuild/.sync-trash/manual-20261011-remove-lucy-master-sync/` (otherwise `both --apply` would copy them back as new files). The engine upgrades (`--mount-a/-b`, labels, free-space guard) stay. Don't re-create a lucy-master sync unless asked. `/mnt/archive` = `lucy-master-bak` (c400a0ee) never had a sync job. Not touched: older additive `sync_lucille_ai.sh` still has a lucy-master (sda4, only if already unlocked) leg.

### project_luks_ventoy_retired.md
_debian@debian · 2026-10-15T01:21:37_

---
name: luks-ventoy-iso-retired
description: "User decision 2026-10-14 — no more LUKS (only slick nvme0n1p6 21GB left), Ventoy and ISOs retired, SWARM/Debian updated live; supersedes the Secure Boot/TPM-unlock plan and the ISO/Ventoy policy"
metadata:
  node_type: memory
  type: project
  originSessionId: f47e78af-8cc6-424b-bb0d-8a22a718f27a
  modified: 2026-10-14T16:48:06.212Z
---

**Decision (user, 2026-10-14):** nothing should use LUKS anymore; Ventoy is gone, so are ISOs; SWARM OS and Debian are updated **live**, not by building ISOs.

**State seen that day:** the T7 (`sda`) was repartitioned (Recovery OS btrfs `96969ed2…` on sda2, sda4 471 GB unformatted); the lucy-master LUKS volume no longer exists. The only LUKS left is `slick` = nvme0n1p6, 21 GB, UUID `019a3cd8-46c5-4a19-a760-8e0c1096b248`, which backs Lucille's `/lucy/unfiltered` mode. The Ventoy stick (sdc, UUID 5ABB-83DF, 23 GB of ISOs) was still plugged in and untouched.

**Why:** simplicity for a one-person hobby project; live updates replace the ISO build/boot-test cycle.

**How to apply:** do not build ISOs, do not suggest Ventoy or LUKS/TPM work; supersedes [[secureboot-and-luks-unlock-plan]] and the ISO policy in CLAUDE.md (docs not yet rewritten). **Slick is the exception: the user said "keep slick" (2026-10-14) — leave it LUKS and untouched; do not export, wipe or reformat it.**

### project_mount_points.md
_debian@debian · 2026-10-10T17:57:40_

---
name: project-mount-points
description: "Mount points and disk layout on i30ltz's machine (updated 2026-10-07) — where Recovery OS goes (former CachyOS partition beside lucy-master), build/read/write rules"
metadata: 
  node_type: memory
  type: project
  originSessionId: d23bd633-72c6-4ffb-a380-378c0a018e26
  modified: 2026-10-09T23:30:34.973Z
---

Layout as of 2026-10-07 (Debian boot; drive letters swap between boots, so always use the UUIDs, see [[feedback-disk-letter-instability]]):

| Mount | What it is |
|---|---|
| `/mnt/Lucy` | LIVE working drive (nvme0n1p4) — SWARM OS source; edits go here (see [[lucy-mount-separation]]) |
| `/mnt/swarmbuild` | SWARM build tree; all ISO builds happen here |
| `/mnt/recoverybuild` | Recovery OS build tree (btrfs `a409250b…`) |
| `/mnt/recoveryos` | Recovery OS installed root — **planned on the former CachyOS partition** (below); not installed yet |
| `/mnt/storage` | The unlocked `lucy-master` LUKS volume (`a24202ce…`, sda4 on the 2026-10-07 boot). Read-only reference per project rules |
| `/mnt/archive` (Debian only) | `lucy-master-bak` (sdb3), backup mirror of lucy-master; read-only by policy |
| `/mnt/endeavor` | Legacy name for the old CachyOS/EndeavourOS root (`ef9acba2…`) — decommissioned |
| `/mnt/boltz` | Optional shared archive, not always attached |
| `/mnt/lucillebuild` | **(2026-10-09)** Lucille Assistant app build — sda8 ext4 `C. Lucille build`, `UUID=93037d5a-5b82-484c-ac20-28211c09e1c0` |
| `/mnt/boltzbuild` | **(2026-10-09)** D = **Boltz Recovery phone app** build (Android companion; NOT the Rust kiosk program, that is B) and the ONLY place that app may live (user) — sda9, **ext4, label `Boltz Built`, UUID `6f7c7656-2984-4fb0-81c8-bfc11ca81461`**, PARTUUID `61b76036-5814-43fa-80b2-84ce5164f3d4` (user reformatted it in GNOME Disks after it was NTFS `67C2E9F8241FD7AE` by mistake; the planned `e195839a…` never existed). Stale fstab/automount: `sudo 70-scripts/fix_boltzbuild_mount.sh`. App at `/mnt/boltzbuild/src/I30LTZ-Recovery-companion` |
| `/mnt/recoveryos` | **(2026-10-09)** Recovery OS root/home — sdb3 btrfs `Recovery OS`, `UUID=490b9e60-afb2-45c6-91ce-2c6b1ea5a2f3` (reformatted; replaces `ef9acba2…`) |

**Update 2026-10-09 — app build partitions (user, verbatim intent):** new mount points `/mnt/lucillebuild` (Lucille Assistant app), `/mnt/boltzbuild` (i30ltz Recovery app), `/mnt/recoveryos` (Recovery OS home). "All build partitions are on one drive" — the 1.8 TB Micron drive: A `/mnt/swarmbuild` sda4, B `/mnt/recoverybuild` sda6, C `/mnt/lucillebuild` sda8, D `/mnt/boltzbuild` sda9 (the Recovery OS root is on the Samsung T7, sdb3). "Everything to build these apps needs to be moved to these partitions" and "all apps need to be able to stand alone once built". The swarmbuild label changed to `A. swarm-build` so `LABEL=swarm-build` no longer matches — use UUID `5c84ef0e-d7b8-4b36-b1c4-58817b483dda`. Debian's fstab had a typo (`/mnt/llucillebuild`), user fixed it the same day; mounting needs root, so run `sudo 70-scripts/apply_app_build_mounts.sh`. Rules are in `/mnt/Lucy/CLAUDE.md` ("App build partitions"). The Recovery OS placement paragraph below is partly superseded: the partition is now `sdb3` / `490b9e60…`, already reformatted.

**Recovery OS placement (user decision 2026-10-07):** root = sda3 (btrfs, 230 GB, label `Cachy OS`, `UUID=ef9acba2-3816-4fd7-bdd7-a9526816d3f0`, the old CachyOS root), EFI = sda1 (`UUID=A367-87E3`, the old CachyOS ESP), directly beside lucy-master (sda4, never touched). This replaces the 2026-09-15 note that `/mnt/endeavor` was the recovery OS's "parent OS", and the earlier RC-11 plan (portable 1.8 TB drive + Debian's ESP `362A-E48F`). CachyOS is decommissioned. Not installed as of 2026-10-07; the Recovery AI owns the install. **Root filesystem must be btrfs** (user: "i do want btrfs", 2026-10-07). **Verified 2026-10-07 via `sudo blkid -p /dev/sda3`:** sda3 is still the original btrfs `Cachy OS` (`ef9acba2…`), NOT ext4 — the "reformatted to ext4" report was wrong and nothing has been erased yet. The fs UUID will change when Recovery OS formats it, so prefer GPT PARTUUIDs — sda3 `993d0098-1b2f-44a2-b51d-11c2bfeddc40`, ESP sda1 `e25e5715-f3b8-4ddb-9796-d1c270804140`, lucy-master sda4 `20a96573-0c80-4393-ba95-40a64964b39e` — and confirm with `sudo blkid -p /dev/sda3` (I'm not in the `disk` group, can't read it).

**Recovery OS must be standalone** (user, 2026-10-08): boots with the Debian disk unplugged — own bootloader on its own ESP sda1 (fallback `\EFI\BOOT\BOOTX64.EFI` + `\EFI\i30ltz` + a firmware entry appended after the existing boot order). Debian itself boots from the other disk (sdb1 ESP `362A-E48F`, `Boot0003 debian`), so Recovery must not rely on Debian's GRUB. Installer: `/mnt/recoverybuild/70-scripts/install-recovery-from-debian.sh` (written, dry-run tested, not run — needs the user's sudo).

**Installed 2026-10-09:** Recovery OS is now installed on sda3 (btrfs `Recovery OS`, NEW `UUID=71287bbf-81bf-4074-9619-4180b5a15742`, supersedes `490b9e60…`/`ef9acba2…`) with its standalone bootloader on sda1 (firmware entry Boot0001, appended last). Not boot-tested yet; Debian's fstab line for `/mnt/recoveryos` still pins the old UUID.

**Why:** User stated this directly 2026-10-07 ("recovery os will go where cachy was beside lucy master", then "sda 1 and 3").

**How to apply:** Never format, mount over or script against sda3/sda1 from SWARM work — Recovery AI does RC-11. Recovery builds stay under `/mnt/recoverybuild`; SWARM work under `/mnt/Lucy`/`/mnt/swarmbuild`. Before trusting any old doc that says "CachyOS" or "/mnt/endeavor", check this note. `/mnt/storage` is no longer "repurposed/unknown": it is the lucy-master volume.

### project_multiple_ai_concurrent.md
_cachyos@cachyos-i30ltz · 2026-09-21T03:45:06_

---
name: project-multiple-ai-concurrent
description: "The user sometimes runs multiple AI agents on /mnt/Lucy at the same time, occasionally without realizing it overlaps — a file mid-edit or a task already half-done may be another AI's live work, not corruption or a stale read"
metadata: 
  node_type: memory
  type: project
  originSessionId: 77f0094d-fd09-40a5-b203-ea52b01a23ed
  modified: 2026-09-21T03:43:05.444Z
---

The user sometimes has **more than one AI agent working on `/mnt/Lucy` concurrently** — not always intentionally. Confirmed directly 2026-09-20: "i did have another ai working at the time i accidentally had yall doing the same thing." This is a standing possibility on this project, not a one-time incident — assume it can happen again on any session. Also confirmed 2026-09-20, same day, twice more: (1) "other AI is on nvidia skills rn" while this session was mid-way through the gaming-overlay work (GamingAgent-go media control, `wry`/`tao` embedded-browser overlay); (2) "forge has been renamed Apex other ai now working on that ide" — see [[project_forge_renamed_apex]] for the naming fact itself. The user actively runs concurrent agents on different areas of the project and expects each session to stay in its own lane rather than assuming the whole repo is exclusively theirs — and proactively tells the session which area to avoid each time, rather than the session needing to detect it.

**Why this matters:** A file that changes between two reads in the same session, a task that's unexpectedly already half-done at session start, or code that doesn't match what `SWARM_AI_FEATURES.md` says was last left — any of these can be a second agent's live or recent work, not corruption, not a stale memory, and not necessarily [[project_auto_sync_commits]]'s ~10-minute auto-commit job (that job explains a *passive* appearance of change; it doesn't explain a task being actively worked mid-session). A 2026-09-19 session correctly detected this from `build_swarm_iso_6.2.19_2026-09-08.sh` changing mid-read and chose to hold off on that whole area rather than push forward — that was the right call.

**How to apply:** If something looks like it's being actively edited out from under a session — a file's content changes between reads with no session-initiated write, a build script gets replaced mid-investigation, generated output appears that nobody in this conversation produced — don't assume it's a bug or a misread. Check `git log --oneline -3 -- <path>` for context, then default to the 2026-09-19 pattern: pause work in that specific area and surface it to the user rather than guessing or plowing ahead. It's fine to keep working in unrelated areas of the project in the meantime — when the user names the area another AI is in (e.g. "nvidia skills"), just avoid that area specifically rather than pausing everything.

### project_phone_terminal_verified.md
_debian@debian · 2026-10-10T17:57:40_

---
name: phone-terminal-sudo-copy-paste
description: Status of the in-app mirrored terminal (I30LTZ Companion / Boltz Recovery) for sudo and copy/paste, what was proven, the agent 0.3.2 fix, and what is still not running on Debian
metadata:
  type: project
---

**User ask (2026-10-10):** "make sure there is an in app mirrored terminal that accepts sudo and copy and paste from the app."

**Verified:** real `i30ltz-node` agent + real tmux: a real `sudo` prompt shows, nothing typed is echoed, CTRL+C cancels, `NoNewPrivs: 0`; a unicode/space password arrives byte-for-byte; a 200 KB paste is bit-for-bit. On an Android 17 emulator against the real `NodeTerminalScreen`: keyboard path, CTRL button, PASTE from the real clipboard into a no-echo prompt, SELECT+COPY into the real clipboard, mirroring. The agent never logs keystrokes. Tests: `AgentIntegrationTest` (opt-in `I30LTZ_NODE_BIN`) and `TerminalWebViewTest` (emulator, `agentHost/agentPort/agentToken`).

**Bug fixed:** agent 0.3.1's `GET /v1/terminal/sessions` was empty without a UTF-8 locale (tmux 3.5 turns the TAB into `_`); agent **0.3.2** (`tmux -u` + UTF-8 env, regression test). Binary `/mnt/recoverybuild/30-source/i30ltz-node/dist/i30ltz-node` (gitignored; old one kept as `...-0.3.1.previous`).

**NOT done:** the agent is not running on Debian (nothing on :7437), so the app's Debian node can't open a terminal; install = user service from `contrib/i30ltz-node.service` (deliberately no `NoNewPrivileges`; gives paired phones a shell as the user, so get the user's go-ahead). Not run on the two real phones (A67LGEN2M202607053035, R5GYC58ZJCA) — never run instrumented tests there: they install a test APK and touch saved nodes/tokens.

**Gotchas for tests:** a process started with `&` inherits SIGINT as ignored (Ctrl-C then stops nothing in tmux) — reset it before exec; tmux sessions outlive a run (stale screen content satisfied two waits) — clear the screen or use a fresh agent; wait for the CONNECT button to be *enabled*; use `ANDROID_SERIAL=emulator-5554`. See [[phone-app-tests]] if it exists, and [[app-build-partitions]].

### project_secureboot_luks_plan.md
_debian@debian · 2026-10-10T17:57:40_

---
name: secureboot-and-luks-unlock-plan
description: User decision 2026-10-10 — enable Secure Boot on all 3 OSes, TPM auto-unlock the lucy-master LUKS volume, keep slick manual; the order of steps, the per-OS PCR 7 gotcha, and what is done/not done
metadata:
  type: project
---

**Decision (user, 2026-10-10):** turn Secure Boot ON, auto-unlock the big encrypted volume ("archive" = the **lucy-master LUKS on the Samsung T7**, sda4, UUID `a24202ce-4d76-4eb7-8923-8e8ddbacdaa7`, inner ext4 mounts at `/mnt/storage`; `/mnt/archive` itself is an UNencrypted partition), and **leave `slick` (LUKS on NVMe p6, UUID `019a3cd8-…`, "Confidential mode") locked/manual**.

**Why/how it protects:** TPM2 unlock releases the key only on this ThinkPad's own boot chain, so a lost T7 alone is useless. It does NOT protect a running, unlocked system (malware, a paired phone's remote shell, anyone logged in), which is why slick stays manual.

**Machine:** Lenovo ThinkPad X13 Gen 1 (BIOS N2YET48W 1.37), TPM 2.0 with sha1+sha256 banks, UEFI, Secure Boot currently OFF, firmware in User Mode (Lenovo PK; db has Lenovo + Microsoft CAs). Debian lacks `cryptsetup`/`systemd-cryptenroll`/`sbctl`/`tpm2-tools` (apt has tpm2-tools; sbctl not in Debian's apt here).

**State of each OS (from `70-scripts/secureboot_preflight.py`, read-only, 9 tests):**
- Debian: shim-signed + grub-efi-amd64-signed + Debian-signed kernels, no DKMS → should just work. Its ESP is root-only readable (needs `sudo` to confirm).
- Recovery OS: installer package list has shim-signed + grub-efi-amd64-signed and `grub-install` picks them automatically → probably works; T7 root/ESP not verified yet (needs sudo).
- SWARM OS (Arch): plain `grub-install`, unsigned kernel `vmlinuz-linux`, no sbctl/shim → WILL NOT BOOT with Secure Boot on until it is signed.

**Order (do NOT enable Secure Boot before SWARM is signed):** (0) run `sudo python3 /mnt/Lucy/70-scripts/secureboot_preflight.py`; (1) `sudo apt install cryptsetup tpm2-tools` and back up both LUKS headers (`cryptsetup luksHeaderBackup`), keep the passphrase slot; (2) SWARM: install `sbctl`, create keys, firmware to Setup Mode (ThinkPad: Security → Secure Boot → reset to Setup Mode / clear keys), `sbctl enroll-keys --microsoft` (keeps Microsoft's CA so Debian's/Recovery's shim keeps working), sign GRUB + kernel, add the re-sign pacman hook; (3) enable Secure Boot and boot-test all three from the F12 menu; (4) ONLY THEN seal the TPM key: `systemd-cryptenroll --tpm2-device=auto --tpm2-pcrs=7 [--tpm2-with-pin=yes] /dev/sda4` + a `crypttab` line with `tpm2-device=auto,nofail` on each OS.

**Gotchas:** (a) PCR 7 includes the certificate that approved each program that started, so Debian (Microsoft→shim) and SWARM (own key) have different PCR 7: enroll the TPM key from EACH OS that should auto-unlock (they add slots; don't `--wipe-slot=tpm2` blindly); Recovery OS probably should stay passphrase-only (zero-dependency rescue). (b) Sealing before keys/Secure Boot are final breaks unlock — the passphrase still works. (c) Firmware reset/BIOS update changes PCRs: re-enroll. (d) Kernel lockdown under Secure Boot blocks unsigned modules and hibernation. (e) Ventoy needs its key enrolled once to boot ISOs under Secure Boot; the SWARM (archiso) ISO is unsigned and won't boot under it.

**Status 2026-10-10 (updated):** the user ran the preflight as root. Debian OK; Recovery OS files OK but its firmware entry `I30LTZ Recovery OS` started Debian-signed `\EFI\i30ltz\grubx64.efi`, which the *firmware* does not trust (only the MS-signed shim does) -> would be refused with Secure Boot on; SWARM OS would not boot (unsigned). Written and tested with stubs (nothing applied to real firmware, Secure Boot still OFF): `70-scripts/secureboot_preflight.py` (12 tests, now checks firmware entries), `/mnt/recoverybuild/70-scripts/repoint_recovery_boot_entry.sh` (+ installer fix to register `shimx64.efi`), `70-scripts/make_swarm_secureboot.sh` (phases check/keys/grub/hooks/enroll/entry/verify, dry-run default, new GRUB at `\EFI\SWARM_OS_SB`, old entry untouched; 11 stub tests; **never run on real Arch**). lucy-master LUKS2 has one passphrase keyslot (keep it); slick is LUKS1 and cannot hold a TPM token. PCR 7 alone lets any Microsoft-signed live USB on this machine unlock -> recommend TPM+PIN. Pending: user runs repoint script, the SWARM phases, firmware Setup Mode + enable, boot-tests, then seals. Stale firmware entries (Ubuntu, Fedora) and `\EFI\cachyos`/`\EFI\refind` are the user's call. See [[app-build-partitions]].

**Applied 2026-10-10 (later):** the user ran `repoint_recovery_boot_entry.sh --apply`: firmware entry `Boot0002 I30LTZ Recovery OS` now starts `\EFI\i30ltz\shimx64.efi` (Boot0001 removed, BootOrder `0003,0000,0004,0005,001F,...,0023,0002`, Debian first). `systemd-cryptsetup` + `tpm2-tools` installed on Debian (`systemd-cryptenroll`, `tpm2_getcap` present; TPM at /dev/tpmrm0 needs sudo, user not in `tss`). lucy-master LUKS header backed up to `~/lucy-master-luks-header.img` (16 MiB, root-only; user should move it off the machine). Next: inside SWARM OS run `make_swarm_secureboot.sh` phases check/keys/grub/hooks, then firmware Setup Mode, enroll/entry, enable Secure Boot, boot-test, then TPM sealing.

### project_steam_cef_crash.md
_cachyos@cachyos-i30ltz · 2026-09-21T01:08:35_

---
name: project-steam-cef-crash
description: "Steam's client crashes on this CachyOS setup unless launched with `-cef-disable-gpu` — not yet wired into any SWARM OS launcher since Steam isn't in the ISO's package list yet"
metadata: 
  node_type: memory
  type: project
  originSessionId: 77f0094d-fd09-40a5-b203-ea52b01a23ed
  modified: 2026-09-21T01:03:54.360Z
---

User installed Steam manually on their CachyOS dev machine (2026-09-20) and found the client crashes on launch unless run as `steam -cef-disable-gpu`. This is Steam's CEF-based UI (friends list/store overlay) failing to init GPU compositing — a known class of issue on some Mesa/driver/compositor combos, not a SWARM OS bug.

**Why this matters:** Steam is not currently in `40-iso-profile/swarm_os_iso_profile/packages.x86_64` and has no `.desktop` launcher or hex-desktop app entry anywhere in the project — this crash was hit on the user's own manual install, not through anything SWARM OS ships. But gaming is a major focus of this project (GamingAgent exists for Steam/GFN integration, and the user has asked for a Steam-overlay-style gameplay HUD), so Steam is very likely to become an actual shipped package + launcher at some point.

**How to apply:** Whenever Steam gets added to the ISO (`packages.x86_64`) and gets a real launcher (`.desktop` entry, hex-desktop tile, or whatever launches it), bake `-cef-disable-gpu` into that launch command by default rather than the bare `steam` binary — otherwise every user of the built ISO hits this same crash on first launch. Don't rediscover this the hard way.

### project_swarm_journey.md
_cachyos@cachyos-i30ltz · 2026-09-16T09:28:08_

---
name: project_swarm-journey
description: "SWARM OS development journey — the ordered task list that guides the build, current progress, and what comes next"
metadata: 
  node_type: memory
  type: project
  originSessionId: 320ba07c-1dec-441e-855c-6376635c294b
  modified: 2026-09-12T07:07:05.883Z
---

# The SWARM OS Journey

The user (i30ltz) is building SWARM OS on a live drive called LUCILLE (`/mnt/Lucy/`). The task list is the **single source of truth** for the journey — read it at the start of every session via `TaskList`.

## Priority order (reordered 2026-09-12: user said "security* boot gaming coding the start on security")

### SECURITY (Tasks #2–3) ← PRIORITY #1 NOW
- **#2** — Podman rootless containers: packages.x86_64, subuid/subgid, registries.conf, podman.socket, DOCKER_HOST env, firejail sandbox isolation. **Code/config fully wired 2026-09-11, not yet boot-tested** (this dev host isn't the target OS — no podman/apparmor here to verify against; needs the next real ISO boot).
- **#3** — Harden baseline: WebAuthn hardware test, ufw firewall, file permissions, auth middleware, AppArmor. **Mostly done 2026-09-11**: discovered the existing `nftables.conf` (default-drop, already predates this session) already satisfies the firewall requirement better than ufw would — installed but deliberately left disabled to avoid fighting nftables over the same tables. AppArmor wired (enforcing on GamingAgent, complain-mode on LucyServer — its dev-platform features are too broad for a first-pass enforcing profile). Auth middleware gap closed on GamingAgent-go (had zero auth; now gated on mutating/key-costing routes, matching LucyServer's existing pattern). **Only remaining item: WebAuthn hardware test** — needs a physical FIDO2 authenticator (discussed DIY options: a plain USB flash drive can't do it, but an RP2040/Pico running Solo2 firmware can, or buy a real key).

### BOOT (Task #1) ← #2 after security
Full hardware boot verification — build ISO, boot from USB, confirm all services start, LUCILLE drive mounts, hex desktop appears. **This must be done before anything else is considered "real," but security hardening runs first.**

### GAMING (Tasks #4–5)
- **#4** — GamingAgent + dashboard live end-to-end test (all APIs, Lucille eval, favorites persistence)
- **#5** — Steam native launch from hex desktop (steam package, launch endpoint, dashboard button, controller)

### CODING (Tasks #6–10)
- **#6** — Container-based dev environments via Podman (LucyServer endpoints, alacritty exec into container)
- **#7** — Claude Code hex tile on real hardware (ANTHROPIC_API_KEY from env, auth flow)
- **#8** — Forge + Coder IDE verification (code-server service on port 8080)
- **#9** — Terminal: tmux + session persistence (alacritty → tmux new-session -A -s swarm)
- **#10** — GitLens + dev tooling tiles (lazygit, meld, real execCommands)

## Key architectural facts
- **Hex desktop** (`hex_desktop_page.dart`): wasp nest wallpaper is the background, icons are transparent hex tiles on top. Infinite circular PageView (N spaces + loop sentinel). Meta+Tab switches spaces. State persists via SharedPreferences.
- **Window manager**: `windowProvider` (Riverpod), 8-handle resize via `resizeWindowFromEdge`, proper left/top edge position+size co-adjustment.
- **Shell**: labwc compositor, Flutter shell + swarm-slint Rust panel, started by `swarm-ui.service`.
- **Containers**: Podman rootless (daemonless, runs as swarm user), Docker-compatible via `DOCKER_HOST`.

## Voices (2026-09-12)
- **Dr. Boltz** — `openrouter/onyx` (OpenRouter → OpenAI tts-1-hd, deep authoritative male). Env: `BOLTZ_TTS_VOICE`.
- **Lucille** — `eleven/EXAVITQu4vr4xnSDxMaL` (ElevenLabs Bella, sultry female). Env: `LUCILLE_TTS_VOICE`.
- OS agents call `/api/tts/generate` with `voiceName="boltz"` or `"lucille"` — same endpoint reused everywhere.
- First boot checklist: `/mnt/Lucy/FIRST_BOOT_CHECKLIST.md` — 14 steps from services check through Syncthing.

## Security work completed 2026-09-12
- Rate limiting middleware added to LucyServer-go (`/lucy` 15/min, `/api/tts/generate` 10/min, `/api/run_command` 30/min) and GamingAgent-go (`/lucille/eval` 5/min, `/lucille/chat`+stream 20/min each). Per-IP fixed-window, no external deps.
- Security headers middleware (`X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`) on all routes in both servers.
- nftables SSH restricted to tailscale0 only — public brute-force surface eliminated.
- Both servers `go build` clean after changes.

## Security incidents found (context for future sessions)
- The stone-cipher lock screen (`cyber_stone_lock_screen.dart`) had a hidden corner-tap gesture (3× top-left, 3× bottom-right) that unlocked the device unconditionally with zero verification — found by the user during the 2026-09-11 hardening session ("fingerprint is for forgotten password but can log you in if you click the right spot"). Fixed: it now requires a bcrypt-verified LucyServer password check and fails closed. **Lesson: don't assume other hidden gestures/debug affordances in this UI are safe — audit similarly before trusting them.**
- `install_swarm_os.sh` baked `User=swarm` into `gaming-agent.service`/`lucy-server.service` but only ever creates `i30ltz` on installed systems — both daemons would have silently failed to start post-install. Fixed by extending the existing user-rename sed block. Worth re-checking any *new* systemd unit added later for the same swarm-vs-i30ltz mismatch.

## Why: user's vision
Lucille is a personal AI OS — stone-and-electric aesthetic, hex wasp-nest desktop, gaming-first, then security, then coding. The journey is boot → harden → play → build.

**How to apply:** At the start of every session, run TaskList to see where we are. Pick up the lowest-numbered incomplete task. Update SWARM_AI_FEATURES.md when anything changes.

### project_swarm_os_standalone.md
_debian@debian · 2026-10-09T19:32:53_

---
name: swarm-os-standalone
description: "User requirement 2026-10-09: installed SWARM OS must run completely off the internal NVMe with all external drives unplugged; what was audited/fixed and the scripts that check/apply it"
metadata:
  type: project
---

**Requirement (user, 2026-10-09):** "SWARM OS needs to run completely off of the internal drive that is standalone." It must boot and work with every external drive unplugged. Required = internal `nvme0n1` p1 ESP (`FE19-A70F`), p2 root (btrfs `f6f706d0…`, `@`/`@home`/`@snapshots`), p3 swap. `/mnt/Lucy` (p4), `/mnt/brains` (p5), `/mnt/slick` (p6) are internal but **optional**. Full rule block: `/mnt/Lucy/CLAUDE.md` "SWARM OS runs standalone". Related: [[app-build-partitions]], [[project-mount-points]].

**Audit result (2026-10-09, static):** installed system `/mnt/swarm/@` — fstab, `root=UUID`, apps in `/opt/swarm_os` all on nvme (`check_swarm_standalone.sh`: 0 FAIL). Soft refs only: swarm-ui logged to `/mnt/Lucy/logs`, parity timer needs an external mirror, GRUB has a Debian chainload to external ESP `362A-E48F`, persona prompt + memory log on p5. Image sources fixed; installed system patched by `sudo 70-scripts/make_installed_swarm_standalone.sh` (user has to run it).

**Why / how to apply:** the installed `swarm-ui.service` has `User=i30ltz` (repo has `swarm`) — patch with targeted edits, never copy the repo file over it. The ESP, `grub.cfg` and UEFI entries need root to inspect (`sudo check_swarm_standalone.sh`). I have NOT boot-tested with externals unplugged — don't claim that. Boot-critical GRUB generators (`add_debian_chainload_to_swarm_grub.sh`, `tidy_swarm_grub_menu.sh`, installer) were deliberately left untouched.

### reference_debian_tailscale_ip.md
_debian@debian · 2026-10-10T17:57:40_

---
name: debian-tailscale-ip
description: The Debian dev PC's Tailscale address 100.82.1.19 (hostname debian) — what runs there and how the phone app knows it
metadata:
  type: reference
---

Debian (this dev PC, hostname `debian`) is **100.82.1.19** on the tailnet (`tailscale0`, user-confirmed and verified 2026-10-09). On that address: LucyServer dev `:5000`, Lucille Assistant `:8403`; the `i30ltz-node` agent (`:7437`) was NOT running on 2026-10-09. Phones on the tailnet: A16 `100.82.1.16`, A17 `100.82.1.17`.

The phone app (Boltz Recovery / I30LTZ Companion) knows Debian through `data/nodes/KnownMachines.kt` — address and name only, never a token (CP-05); add more machines there. See [[app-build-partitions]].

### reference_swarm_shared_memory.md
_cachyos@cachyos-i30ltz · 2026-09-16T09:28:42_

---
name: reference-swarm-shared-memory
description: "Shared memory across all 3 OSes, phones and Claude lives at /mnt/brains/swarm-memory — read PROJECT_MEMORY.md there; this memory dir itself syncs through it"
metadata: 
  node_type: memory
  type: reference
  originSessionId: a02d8c32-3e53-4503-b60f-59b34cb1218f
  modified: 2026-09-16T09:28:18.763Z
---

SWARM OS shared memory (built 2026-09-16): an append-only log at `/mnt/brains/swarm-memory/log/<device>.jsonl`, shared by CachyOS, SWARM OS, EndeavourOS, the three companion phones, and this Claude memory directory.

- Read `/mnt/brains/swarm-memory/PROJECT_MEMORY.md` for decisions, facts and notes written from other devices.
- Record a durable decision so every device sees it: `swarm-memory add -kind decision -key <topic> "text"`.
- This memory directory is synced both ways by `swarm-memory claude` (runs in `swarm-memory tick`, every 5 min via timer). Files written here appear on the other OSes and phones; edits from there land here.
- Git copy: `/mnt/Lucy/60-boltz-brain/swarm-memory/` (auto_sync_github.sh). Spec: `/mnt/Lucy/90-docs/SWARM_MEMORY_SYNC_v1.0.0_2026-09-16.md`.

Related: [[project-mount-points]], [[feedback-lucy-mount-separation]]

### user_hobby_enterprise_quality.md
_debian@debian · 2026-10-10T17:57:40_

---
name: hobby-project-enterprise-quality
description: The whole SWARM/Lucille/Recovery suite is a personal passion hobby on a limited budget; "enterprise level" means enterprise QUALITY, not enterprise features or customers
metadata:
  type: user
---

The user (i30ltz) builds SWARM OS, Lucille, Recovery OS and the two phone apps alone, as a hobby they are passionate about. "Enterprise level" (their words, 2026-10-10) = enterprise **quality** (tests, safety, honest docs, no data loss), NOT enterprise features/process/customers. They want it as polished and cool as possible in case anyone ever sees it.

**Why:** they clarified this deliberately ("it's just a hobby, but I want enterprise quality"). The money is personal and limited (they pay for AI out of a tight personal budget), and they care a lot about not wasting it.

**How to apply:** do not over-engineer for imaginary scale or compliance; do hold the quality bar high (verify, test, fail safe). Prefer cheap-to-run, simple-to-maintain solutions; avoid wasteful paid API calls, huge parallel agent runs or token-heavy experiments unless they are worth it. This is also written at the top of `/mnt/Lucy/CLAUDE.md` and `AGENTS.md`. Personal details they shared (health, grocery budget) are deliberately NOT written into repo files, because Lucy's repo auto-pushes to GitHub. Related: [[app-build-partitions]].

## Core documents (full text in the log; originals on /mnt/brains)
- `Dr_Boltz_Core_Prompt.md` — 2317 bytes, updated 2026-09-16T09:28:08 by `cachyos@cachyos-i30ltz`
- `Lucy_Core_Prompt.md` — 2248 bytes, updated 2026-09-16T09:28:08 by `cachyos@cachyos-i30ltz`
- `llcy_memory.md` — 2310 bytes, updated 2026-09-16T09:28:08 by `cachyos@cachyos-i30ltz`
- `lucille_personas_memory.json` — 22157 bytes, updated 2026-09-16T09:28:08 by `cachyos@cachyos-i30ltz`
- `memory.json` — 208835 bytes, updated 2026-09-16T09:28:08 by `cachyos@cachyos-i30ltz`
- `users.json` — 228749 bytes, updated 2026-09-16T09:28:08 by `cachyos@cachyos-i30ltz`

## Recent notes (newest first, last 100)

- **2026-09-25T19:53** `cachyos@cachyos-i30ltz` note — lucille-core: Engine↔Router↔Pipeline wiring complete. LucilleEngine owns SwarmRouter; HITL injected engine→router; route_pipeline_full() chains Kimi streaming → DeepSeek concurrent audit → consensus gate → HITL phone approval → checkpoint/apply. Structured metric logging (JSON stdout + SHM ring). IPC commands route_task/run_pipeline. 172 pass / 0 fail, 2 pre-existing TSan in ProcessM…
