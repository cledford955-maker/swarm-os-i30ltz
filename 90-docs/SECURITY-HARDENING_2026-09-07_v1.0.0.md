# LucyServer security hardening
`2026-09-07 · v1.0.0 · applied to 30-source/LucyServer`

Applied because the SWARM Companion IDE reaches LucyServer over the network,
which turns three local-only conveniences into remote attack surface.

Originals archived:
`99-archive/superseded/Program_2026-09-07_pre-hardening.cs`
`99-archive/superseded/FileSystemService_2026-09-07_pre-hardening.cs`

## 1. Auth token now fails closed — `Program.cs`

Was: `GetEnvironmentVariable("SWARM_AUTH_TOKEN") ?? "swarm-token-2026"`.
Every copy of the source carried the working credential for a host exposing
`/api/run_command` and `/api/terminal/ws`.

Now: no default. The server throws at startup if the token is unset, is the
retired literal, or is under 16 characters. Comparison is
`CryptographicOperations.FixedTimeEquals`, and `Authorization` must be an exact
`Bearer <token>` — the old code used `.Contains()`, which accepted any header
that merely embedded the token. Loopback still bypasses the header, so the
local Flutter shell is unaffected.

## 2. Filesystem API clamped to a root — `Services/FileSystemService.cs`

Was: `/api/fs` defaulted to `path = "/"`, and `ReadFileAsync` / `SaveFileAsync`
accepted any absolute path. An authenticated phone could read or overwrite any
file the server user could.

Now: every request path goes through `ResolveWithinRoot()`, which resolves
`..`, follows a final symlink so a link cannot step outside, and refuses
anything not under `SWARM_PROJECT_ROOT` (falling back to `$HOME`, never `/`).
Applied to list, analyze, code-files, read, save and apply-upgrade.
The service is resolved eagerly at startup so a bad root fails fast.

## 3. Command injection removed — `AnalyzeDirectoryAsync`

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
