#!/usr/bin/env python3
# ╔══════════════════════════════════════════════════════════════════════╗
# ║  SWARM_OS Graphical Installer — backend                             ║
# ║  Version: 1.0.0 | Date: 2026-10-05                                  ║
# ║  Drives /usr/local/bin/install_swarm_os.sh --non-interactive        ║
# ║  Python stdlib ONLY — no pip dependencies.                          ║
# ╚══════════════════════════════════════════════════════════════════════╝
"""
Local-only HTTP server that presents the Lucille-themed install wizard and
drives the proven install_swarm_os.sh script in --non-interactive mode.

Design rules:
  * Binds 127.0.0.1 only. Never reachable off-box.
  * Single-use CSRF token minted at startup, embedded in the page.
  * The password is POSTed once, written to a 0600 file under a 0700
    directory, and handed to the installer via --password-file. The
    installer reads it once and unlinks it. It is never logged, never
    placed on a command line, and never echoed back to the client.
  * The install subprocess is spawned exactly once per server lifetime.
  * Log output is streamed to the browser via Server-Sent Events.
"""

import json
import os
import queue
import re
import secrets
import shutil
import stat
import subprocess
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

VERSION = "1.0.0"
BUILD_DATE = "2026-10-05"

HERE = Path(__file__).resolve().parent
WEB_ROOT = HERE / "web"

INSTALLER = os.environ.get(
    "SWARM_INSTALLER_SCRIPT", "/usr/local/bin/install_swarm_os.sh"
)
RUN_DIR = Path(os.environ.get("SWARM_INSTALLER_RUNDIR", "/run/swarm-installer"))
# Set SWARM_INSTALLER_DRYRUN=1 to exercise the whole UI without touching a disk.
DRY_RUN = os.environ.get("SWARM_INSTALLER_DRYRUN", "0") == "1"

CSRF_TOKEN = secrets.token_urlsafe(32)

# ─── install job state ───────────────────────────────────────────────────
_SENTINEL = object()  # pushed to subscribers the instant the job finishes


class Job:
    def __init__(self):
        self.lock = threading.Lock()
        self.state = "idle"          # idle | running | success | failed
        self.started = False
        self.returncode = None
        self.lines = []              # full transcript, for late subscribers
        self.subscribers = []        # list[queue.Queue]
        self.disk = None

    def publish(self, line):
        with self.lock:
            self.lines.append(line)
            self._fanout(line)

    def complete(self, state, returncode):
        """Mark the job finished and wake every subscriber immediately.

        Without the sentinel, an SSE reader sits on its queue timeout before
        noticing the state change, leaving the UI on the progress screen for
        seconds after the install actually finished.
        """
        with self.lock:
            self.state = state
            self.returncode = returncode
            self._fanout(_SENTINEL)

    def _fanout(self, item):
        dead = []
        for q in self.subscribers:
            try:
                q.put_nowait(item)
            except queue.Full:
                dead.append(q)
        for q in dead:
            self.subscribers.remove(q)

    def subscribe(self):
        q = queue.Queue(maxsize=10000)
        with self.lock:
            backlog = list(self.lines)
            self.subscribers.append(q)
        return q, backlog

    def unsubscribe(self, q):
        with self.lock:
            if q in self.subscribers:
                self.subscribers.remove(q)


JOB = Job()


# ─── disk enumeration ────────────────────────────────────────────────────
# Kernel device-name prefixes that are never a valid install target.
# zram/loop/dm are virtual; sr/fd are optical/floppy; md is an assembled array.
VIRTUAL_PREFIXES = ("zram", "loop", "dm-", "sr", "fd", "md", "ram", "nbd")

# Mountpoints that indicate the running live medium, per bootloader family.
LIVE_HINTS = (
    "/run/archiso/bootmnt",   # archiso (SWARM_OS)
    "/run/archiso/airootfs",
    "/run/live/medium",       # Debian live-build
    "/cdrom",                 # casper / Ubuntu
    "/lib/live/mount/medium",
    "/isodevice",
)


def live_medium_disks():
    """Kernel names of the disk(s) backing the running live medium.

    This is the single most important guard in the installer: booted from a
    Ventoy USB, that USB is an ordinary removable disk and would otherwise be
    offered as a target. Wiping it mid-install destroys the installer that is
    currently executing. Never offer it.
    """
    names = set()
    try:
        with open("/proc/self/mountinfo", encoding="utf-8") as fh:
            mountinfo = fh.read().splitlines()
    except OSError:
        return names

    sources = set()
    for line in mountinfo:
        parts = line.split()
        try:
            sep = parts.index("-")
        except ValueError:
            continue
        mountpoint = parts[4]
        if any(mountpoint.startswith(h) for h in LIVE_HINTS):
            if len(parts) > sep + 2:
                sources.add(parts[sep + 2])

    # Resolve each source device back to its parent whole disk.
    for src in sources:
        if not src.startswith("/dev/"):
            continue
        try:
            out = subprocess.run(
                ["lsblk", "-nso", "NAME", src],
                capture_output=True, text=True, timeout=10, check=True,
            ).stdout
            # -s inverts the tree: last line is the top-most parent disk.
            chain = [ln.strip() for ln in out.splitlines() if ln.strip()]
            if chain:
                names.add(chain[-1])
        except Exception:  # noqa: BLE001
            continue
    return names


def list_disks():
    """Enumerate candidate install targets via lsblk.

    Mirrors the safety posture of install_swarm_os.sh: removable media and
    disks holding a LUKS partition are surfaced but flagged, never silently
    offered as the default. Virtual devices and the live boot medium are
    excluded outright — they are never legitimate targets.
    """
    try:
        out = subprocess.run(
            ["lsblk", "-J", "-b", "-o",
             "NAME,PATH,SIZE,TYPE,RM,RO,MODEL,TRAN,MOUNTPOINT,FSTYPE"],
            capture_output=True, text=True, timeout=15, check=True,
        ).stdout
        tree = json.loads(out)
    except Exception as exc:  # noqa: BLE001
        return [], f"lsblk failed: {exc}"

    live = live_medium_disks()
    disks = []
    excluded = []

    for dev in tree.get("blockdevices", []):
        name = dev.get("name") or ""
        if dev.get("type") != "disk":
            continue
        if name.startswith(VIRTUAL_PREFIXES):
            excluded.append(f"{name} (virtual device)")
            continue
        if name in live:
            excluded.append(f"{name} (live boot medium — currently running)")
            continue

        size = dev.get("size") or 0
        if size < 8 * 1024**3:  # under 8 GiB cannot hold SWARM_OS
            excluded.append(f"{name} (too small: {human(size)})")
            continue

        children = dev.get("children") or []
        has_luks = any(c.get("fstype") == "crypto_LUKS" for c in children)
        mounted = [c.get("mountpoint") for c in children if c.get("mountpoint")]

        warnings = []
        if dev.get("rm"):
            warnings.append("removable")
        if dev.get("ro"):
            warnings.append("read-only")
        if has_luks:
            warnings.append("contains LUKS — likely a reference/archive drive")
        if mounted:
            warnings.append(
                "has mounted partitions: "
                + ", ".join(sorted(m for m in mounted if m))
            )

        disks.append({
            "path": dev.get("path"),
            "name": name,
            "size": size,
            "size_h": human(size),
            "model": (dev.get("model") or "").strip() or "unknown",
            "tran": (dev.get("tran") or "").strip(),
            "partitions": len(children),
            "warnings": warnings,
            "safe": not warnings,
        })

    disks.sort(key=lambda d: (not d["safe"], -d["size"]))
    return disks, None, excluded


def human(n):
    try:
        n = float(n)
    except (TypeError, ValueError):
        return "?"
    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        if n < 1024 or unit == "TiB":
            return f"{n:.1f} {unit}" if unit != "B" else f"{int(n)} B"
        n /= 1024
    return "?"


# ─── privilege escalation ────────────────────────────────────────────────
def privileged_prefix():
    """Pick how to become root. Live ISO grants the live user NOPASSWD sudo.

    Order: sudo -n (non-interactive, fails fast if not permitted), then
    pkexec. If already root, no prefix. Returns None if no route exists.
    """
    if os.geteuid() == 0:
        return []
    if shutil.which("sudo"):
        probe = subprocess.run(
            ["sudo", "-n", "true"], capture_output=True, text=True
        )
        if probe.returncode == 0:
            return ["sudo", "-n"]
    if shutil.which("pkexec"):
        return ["pkexec"]
    return None


def stage_password(password: str) -> Path:
    """Write the password to a 0600 file inside a 0700 dir.

    Rationale (same as the installer's own comment): a command-line argument
    is world-visible via /proc/<pid>/cmdline; a file only the owner and root
    can read is not. install_swarm_os.sh reads it once and unlinks it.
    """
    RUN_DIR.mkdir(parents=True, exist_ok=True)
    os.chmod(RUN_DIR, stat.S_IRWXU)  # 0700
    fd = os.open(
        str(RUN_DIR / "passwd"),
        os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW,
        0o600,
    )
    try:
        os.write(fd, password.encode("utf-8"))
    finally:
        os.close(fd)
    return RUN_DIR / "passwd"


# ─── install runner ──────────────────────────────────────────────────────
def run_install(disk: str, password: str):
    JOB.disk = disk
    JOB.state = "running"
    JOB.publish(f"=== SWARM_OS Installer v{VERSION} ({BUILD_DATE}) ===")
    JOB.publish(f"Target disk : {disk}")
    JOB.publish(f"Installer   : {INSTALLER}")
    if DRY_RUN:
        JOB.publish("MODE        : DRY RUN — no disk will be touched")

    prefix = privileged_prefix()
    if prefix is None:
        JOB.publish("FATAL: no way to gain root (need sudo -n or pkexec).")
        JOB.complete("failed", 127)
        return

    if not DRY_RUN and not Path(INSTALLER).exists():
        JOB.publish(f"FATAL: installer script not found at {INSTALLER}")
        JOB.complete("failed", 127)
        return

    try:
        pw_path = stage_password(password)
    except OSError as exc:
        JOB.publish(f"FATAL: could not stage password file: {exc}")
        JOB.complete("failed", 1)
        return
    finally:
        del password  # drop the plaintext from this frame

    if DRY_RUN:
        cmd = prefix + [
            "/bin/sh", "-c",
            "echo '[dry-run] would exec: install_swarm_os.sh --disk "
            f"{disk} --non-interactive --password-file <staged>'; "
            "for i in 1 2 3 4 5; do echo \"[dry-run] step $i/5\"; sleep 1; done; "
            f"rm -f {pw_path}; echo '[dry-run] complete'",
        ]
    else:
        cmd = prefix + [
            INSTALLER,
            "--disk", disk,
            "--non-interactive",
            "--password-file", str(pw_path),
        ]

    JOB.publish("")
    try:
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            env={**os.environ, "TERM": "dumb"},
        )
    except Exception as exc:  # noqa: BLE001
        JOB.publish(f"FATAL: could not start installer: {exc}")
        _shred(pw_path)
        JOB.complete("failed", 1)
        return

    ansi = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")
    for raw in proc.stdout:
        JOB.publish(ansi.sub("", raw.rstrip("\n")))
    proc.wait()
    _shred(pw_path)

    if proc.returncode == 0:
        JOB.publish("")
        JOB.publish("=== Installation completed successfully ===")
        JOB.complete("success", proc.returncode)
    else:
        JOB.publish("")
        JOB.publish(f"=== Installer exited with code {proc.returncode} ===")
        JOB.complete("failed", proc.returncode)


def _shred(path: Path):
    """Best effort: the installer unlinks this itself, but if it died early
    the plaintext must not survive on the live filesystem."""
    try:
        if path.exists():
            size = path.stat().st_size
            with open(path, "r+b") as fh:
                fh.write(b"\0" * size)
                fh.flush()
                os.fsync(fh.fileno())
            path.unlink()
    except OSError:
        pass


# ─── HTTP ────────────────────────────────────────────────────────────────
class Handler(BaseHTTPRequestHandler):
    server_version = f"swarm-installer/{VERSION}"

    def log_message(self, fmt, *args):  # quieter console
        sys.stderr.write("[http] %s\n" % (fmt % args))

    # -- helpers ---------------------------------------------------------
    def _send(self, code, body=b"", ctype="text/plain; charset=utf-8", extra=None):
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        if body:
            self.wfile.write(body)

    def _json(self, code, obj):
        self._send(code, json.dumps(obj).encode(), "application/json; charset=utf-8")

    def _guard_local(self):
        host = (self.client_address[0] or "")
        if host not in ("127.0.0.1", "::1"):
            self._send(403, b"local access only")
            return False
        return True

    # -- routes ----------------------------------------------------------
    def do_GET(self):  # noqa: N802
        if not self._guard_local():
            return
        path = self.path.split("?", 1)[0]

        if path in ("/", "/index.html"):
            page = (WEB_ROOT / "index.html").read_text(encoding="utf-8")
            page = page.replace("__CSRF_TOKEN__", CSRF_TOKEN)
            page = page.replace("__VERSION__", VERSION)
            page = page.replace("__BUILD_DATE__", BUILD_DATE)
            page = page.replace("__DRY_RUN__", "true" if DRY_RUN else "false")
            self._send(200, page.encode(), "text/html; charset=utf-8")
            return

        if path == "/api/disks":
            disks, err, excluded = list_disks()
            self._json(200, {"disks": disks, "error": err, "excluded": excluded})
            return

        if path == "/api/status":
            self._json(200, {
                "state": JOB.state,
                "returncode": JOB.returncode,
                "disk": JOB.disk,
                "version": VERSION,
                "dry_run": DRY_RUN,
            })
            return

        if path == "/api/log":
            self._stream_log()
            return

        if path.startswith("/web/"):
            rel = path[len("/web/"):]
            target = (WEB_ROOT / rel).resolve()
            if WEB_ROOT not in target.parents or not target.is_file():
                self._send(404, b"not found")
                return
            ctype = {
                ".css": "text/css", ".js": "application/javascript",
                ".svg": "image/svg+xml", ".png": "image/png",
            }.get(target.suffix, "application/octet-stream")
            self._send(200, target.read_bytes(), ctype)
            return

        self._send(404, b"not found")

    def do_POST(self):  # noqa: N802
        if not self._guard_local():
            return
        path = self.path.split("?", 1)[0]

        if path not in ("/api/install", "/api/reboot"):
            self._send(404, b"not found")
            return

        if self.headers.get("X-CSRF-Token") != CSRF_TOKEN:
            self._json(403, {"error": "bad csrf token"})
            return

        if path == "/api/reboot":
            # Only ever honoured after a finished install — refusing otherwise
            # keeps a stray request from killing a running install.
            if JOB.state not in ("success", "failed"):
                self._json(409, {"error": "install not finished"})
                return
            if DRY_RUN:
                self._json(200, {"rebooting": False, "dry_run": True})
                return
            prefix = privileged_prefix()
            if prefix is None:
                self._json(500, {"error": "no privilege route for reboot"})
                return
            self._json(200, {"rebooting": True})
            threading.Thread(
                target=lambda: subprocess.run(prefix + ["systemctl", "reboot"]),
                daemon=True,
            ).start()
            return

        try:
            length = int(self.headers.get("Content-Length") or 0)
            payload = json.loads(self.rfile.read(length) or b"{}")
        except (ValueError, json.JSONDecodeError):
            self._json(400, {"error": "malformed body"})
            return

        disk = (payload.get("disk") or "").strip()
        password = payload.get("password") or ""
        confirm = (payload.get("confirm") or "").strip()

        # Validate the disk against the live enumeration — never trust the
        # client to hand us an arbitrary path to feed a destructive script.
        disks, _, _ = list_disks()
        valid = {d["path"] for d in disks}
        if disk not in valid:
            self._json(400, {"error": f"{disk!r} is not a current install target"})
            return
        if not re.fullmatch(r"/dev/[a-zA-Z0-9/_-]+", disk):
            self._json(400, {"error": "disk path failed validation"})
            return
        if confirm != disk:
            self._json(400, {"error": "confirmation text does not match the disk path"})
            return
        if len(password) < 1:
            self._json(400, {"error": "password required"})
            return

        with JOB.lock:
            if JOB.started:
                self._json(409, {"error": "an install has already been started"})
                return
            JOB.started = True

        threading.Thread(
            target=run_install, args=(disk, password), daemon=True
        ).start()
        self._json(202, {"started": True, "disk": disk})

    # -- SSE -------------------------------------------------------------
    def _stream_log(self):
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream; charset=utf-8")
        self.send_header("Cache-Control", "no-store")
        self.send_header("Connection", "close")
        self.send_header("X-Accel-Buffering", "no")
        self.end_headers()
        # SSE has no Content-Length; without an explicit close the client
        # waits on a keep-alive socket after the terminal event.
        self.close_connection = True

        q, backlog = JOB.subscribe()
        try:
            for line in backlog:
                self._sse("line", line)
            # A late subscriber attaching after the job ended gets the
            # transcript above, then the terminal event right away.
            if JOB.state in ("success", "failed"):
                self._sse("done", json.dumps(
                    {"state": JOB.state, "returncode": JOB.returncode}))
                return
            while True:
                try:
                    item = q.get(timeout=15)
                except queue.Empty:
                    self._sse("ping", "")       # keep the connection warm
                    continue
                if item is _SENTINEL:
                    self._sse("done", json.dumps(
                        {"state": JOB.state, "returncode": JOB.returncode}))
                    break
                self._sse("line", item)
        except (BrokenPipeError, ConnectionResetError):
            pass
        finally:
            JOB.unsubscribe(q)

    def _sse(self, event, data):
        chunk = f"event: {event}\n"
        for ln in str(data).split("\n"):
            chunk += f"data: {ln}\n"
        chunk += "\n"
        self.wfile.write(chunk.encode("utf-8"))
        self.wfile.flush()


def main():
    port = int(os.environ.get("SWARM_INSTALLER_PORT", "0"))
    httpd = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    actual = httpd.server_address[1]
    url = f"http://127.0.0.1:{actual}/"

    # The launcher reads this line to know where to point the browser.
    print(f"SWARM_INSTALLER_URL={url}", flush=True)
    print(f"[swarm-installer] v{VERSION} ({BUILD_DATE}) listening on {url}",
          file=sys.stderr, flush=True)
    if DRY_RUN:
        print("[swarm-installer] DRY RUN — no disk will be modified",
              file=sys.stderr, flush=True)

    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        httpd.server_close()


if __name__ == "__main__":
    main()
