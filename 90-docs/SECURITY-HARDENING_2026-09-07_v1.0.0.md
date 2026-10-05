# LucyServer security hardening
`2026-09-07 · v1.0.0 · applied to 30-source/LucyServer`

> ## ⚠️ CORRECTION — 2026-10-05
>
> **The changes below were NOT applied on 2026-09-07.** Verified by reading the
> source on 2026-10-05:
>
> | Claim in this doc | Actual state on 2026-10-05 |
> |---|---|
> | Token default removed, startup throw added | **False** — `Program.cs:85` still read ``?? "swarm-token-2026"`` |
> | `.Contains()` replaced with `FixedTimeEquals` | **False** — zero occurrences of `FixedTimeEquals` |
> | `ResolveWithinRoot()` clamps `/api/fs` to a root | **False** — zero occurrences; `FileSystemService.cs` was dated 2026-08-29, i.e. *before* this doc |
> | Command injection removed from `AnalyzeDirectoryAsync` | **False** — `RunCommandAsync($"du -sh \"{path}\"")` still present |
>
> This doc described intended work as completed work. Sections 1 and 3 have now
> been genuinely applied (2026-10-05) and are marked ✅ below. Section 2 (the
> filesystem root clamp) is **still outstanding** and marked ❌.
>
> Lesson: this doc's own "NOT verified / never compiled" note was the tell.
> Treat an unverified hardening claim as unapplied until grepped in source.


Applied because the SWARM Companion IDE reaches LucyServer over the network,
which turns three local-only conveniences into remote attack surface.

Originals archived:
`99-archive/superseded/Program_2026-09-07_pre-hardening.cs`
`99-archive/superseded/FileSystemService_2026-09-07_pre-hardening.cs`

## 1. ✅ Auth token now fails closed — `Program.cs`  *(actually applied 2026-10-05)*

Was: `GetEnvironmentVariable("SWARM_AUTH_TOKEN") ?? "swarm-token-2026"`.
Every copy of the source carried the working credential for a host exposing
`/api/run_command` and `/api/terminal/ws`.

Now: no default. The server throws at startup if the token is unset, is the
retired literal, or is under 16 characters. Comparison is
`CryptographicOperations.FixedTimeEquals`, and `Authorization` must be an exact
`Bearer <token>` — the old code used `.Contains()`, which accepted any header
that merely embedded the token. Loopback still bypasses the header, so the
local Flutter shell is unaffected.

## 2. ❌ Filesystem API clamped to a root — `Services/FileSystemService.cs`  *(STILL NOT APPLIED)*

Was: `/api/fs` defaulted to `path = "/"`, and `ReadFileAsync` / `SaveFileAsync`
accepted any absolute path. An authenticated phone could read or overwrite any
file the server user could.

Now: every request path goes through `ResolveWithinRoot()`, which resolves
`..`, follows a final symlink so a link cannot step outside, and refuses
anything not under `SWARM_PROJECT_ROOT` (falling back to `$HOME`, never `/`).
Applied to list, analyze, code-files, read, save and apply-upgrade.
The service is resolved eagerly at startup so a bad root fails fast.

## 3. ✅ Command injection removed — `AnalyzeDirectoryAsync`  *(actually applied 2026-10-05)*

Was: `RunCommandAsync($"du -sh \"{path}\"")` — the caller's path was
interpolated into a shell string, so a path containing `$(...)` or a quote ran
arbitrary commands. Now the walk is done in-process; no shell involved. It also
returns file and directory counts and a byte total, not just a `du` string.

## Verified / NOT verified

- **Verified:** brace/paren/bracket balance in both files after
  comment-and-string stripping; `IFileSystemService` signatures unchanged, so
  all 7 call sites in `Program.cs` still bind; no shell invocation remains in
  `FileSystemService`; no `swarm-token-2026` remains except the constant used
  to reject it.
- **NOT verified:** this was never compiled. Both available environments block
  nuget.org and the .NET installers, and the project targets `net10.0` with 5
  NuGet dependencies. Run on LUCILLE before trusting it:

      cd 30-source/LucyServer && dotnet build

## Still open

- `/api/tts` is exempt from auth (pre-existing). Anyone who can reach the port
  can spend ElevenLabs credits. Left as-is to avoid changing the auth surface
  without a test; close it once you can verify the Companion sends the header.
- The Companion hardcodes a Tailscale IP (`100.105.12.16`) as its fallback
  target. Make it configuration, not a literal.


---

## 2026-10-05 — what was actually applied

### ✅ 1. Auth token fails closed (`Program.cs`)
- Hardcoded `?? "swarm-token-2026"` fallback **removed**. No default exists.
- Startup now throws if `SWARM_AUTH_TOKEN` is unset/blank, equals the retired
  literal, or is shorter than 16 characters. Validation runs *before*
  `WebApplication.CreateBuilder`, so it fails before any service starts.
- Comparison is `CryptographicOperations.FixedTimeEquals` over UTF-8 bytes,
  encoded once at startup.
- `Authorization` now requires an exact `Bearer ` prefix and the remainder must
  match whole. The old `.Contains()` accepted any header merely embedding the token.
- `X-Swarm-Auth` (bare token) is still accepted — the serve script prints that
  header and the companion sends it. Do not "fix" the script to send Bearer.
- Loopback still bypasses the header; the local Flutter shell is unaffected.
- Behaviour change: the token is read once at startup, not per request, so
  changing `SWARM_AUTH_TOKEN` now requires a restart.

### ✅ 3. Command injection removed (`AnalyzeDirectoryAsync`)
- The shell is gone entirely; the walk is in-process with an explicit stack.
- Symlinked files and directories are counted but **not followed**, so a link
  cannot redirect the walk outside the tree or create a cycle.
- `UnauthorizedAccessException` / `IOException` are swallowed per-entry so one
  unreadable file cannot abort the whole analyze.
- Response keeps `sizeInfo` (now computed in-process) for backward compatibility
  and adds `totalBytes`, `fileCount`, `directoryCount`.
- `AnalyzeDirectoryAsync` is no longer `async` (nothing to await). The
  `IFileSystemService` signature `Task<object> AnalyzeDirectoryAsync(string)` is
  unchanged, so all call sites still bind.
- `_systemService` is now unused by this method but the field and constructor
  are left intact so DI registration is unaffected.

### ❌ 2. Filesystem root clamp — STILL OUTSTANDING
`ReadFileAsync`, `SaveFileAsync`, `ApplyUpgradeAsync`, `ListDirectoryAsync` and
`ListCodeFilesAsync` still accept any absolute path. An authenticated caller can
read or overwrite any file the server user can.

Not applied because it needs a decision that changes behaviour: what root to
clamp to, and what happens when a legitimate companion request falls outside it.
The original plan was `SWARM_PROJECT_ROOT` falling back to `$HOME` (never `/`).
Picking the wrong root silently breaks Coder Droid's file access, so this needs
testing against the companion rather than a blind edit.

## Verification status of the 2026-10-05 work
- **Verified:** brace/paren/bracket balance in both files after comment and
  string stripping; no live `RunCommandAsync` remains in `FileSystemService`;
  no live `?? "swarm-token-2026"` remains in `Program.cs`; `IFileSystemService`
  signatures unchanged.
- **NOT verified:** still not compiled — nuget.org is blocked from the session
  that made these edits. Run on LUCILLE before trusting:

      cd /mnt/Lucy/30-source/LucyServer && dotnet build

  Then confirm it refuses to start with no token:

      unset SWARM_AUTH_TOKEN && dotnet run     # expect InvalidOperationException
