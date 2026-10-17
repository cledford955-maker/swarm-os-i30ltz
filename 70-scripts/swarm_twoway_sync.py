#!/usr/bin/env python3
"""Two-way sync of /mnt/Lucy (side A, source of truth) and /mnt/swarmbuild (side B, build tree).

The point of this tool, in one sentence: a file that exists on only ONE side is either NEW (create it on the other
side) or DELETED on the other side (delete it here too), and plain rsync cannot tell which. This tool remembers.

How it knows
  After every successful run it stores, per path, what BOTH sides looked like (a manifest in SQLite).
  Next run, for a path present on one side only:
      never in the manifest      -> it was created here          -> copy it to the other side
      in the manifest, unchanged -> the other side deleted it    -> delete it here too (to trash)
      in the manifest, but edited here since -> deleted over there, edited here: the EDIT WINS, copy it back
  For a path present on both sides but different:
      changed on one side only   -> copy that side's version over
      changed on both            -> conflict: the newer file wins, the loser is kept in the trash

Safety
  * Dry run unless --apply. Nothing is ever destroyed: deletions and overwrites move the old file to
    <root>/.sync-trash/<run>/ (pruned after 30 days, always keeping the last 5 runs).
  * Refuses if a root is not a mount point, if its filesystem is not the one the manifest was made with, if an ISO build
    holds the build lock, or if the plan deletes suspiciously many files (an unmounted or emptied side looks exactly like
    "everything was deleted").
  * A directory it cannot read is treated as UNKNOWN, never as "deleted": nothing under it is touched on either side.
  * Files that change between the scan and the copy are skipped and picked up next run.
  * Excluded paths (swarm_sync.exclude: .git, build output, installer chroot, ...) are never read, copied or deleted.

Exit status: 0 done / nothing to do, 1 refused or bad usage, 2 finished but something needs a look (conflicts, failures).
"""
from __future__ import annotations

import argparse
import fcntl
import filecmp
import fnmatch
import json
import os
import shutil
import sqlite3
import stat
import subprocess
import sys
import tempfile
import time
from pathlib import Path

DEFAULT_A = "/mnt/Lucy"
DEFAULT_B = "/mnt/swarmbuild"
STATE_DIR_NAME = ".swarm-sync"
TRASH_DIR_NAME = ".sync-trash"
KEEP_TRASH_DAYS = 30
KEEP_TRASH_RUNS = 5
HERE = Path(__file__).resolve().parent
_open_files = []  # handles to close when a run ends, even by a crash
DEFAULT_RULES = HERE / "swarm_sync.exclude"
# Always excluded, whatever the rules file says: our own state and trash, and live git internals.
BUILTIN_RULES = [f"/{TRASH_DIR_NAME}/", f"/{STATE_DIR_NAME}/", "/.git/"]


# --------------------------------------------------------------------------------------------- exclude rules
class Rules:
    """gitignore-like excludes. '/x' anchors at the root, 'x/' matches directories only, '*' stays inside one path
    component, '**/x' matches at any depth, '!x' re-includes. The last matching rule wins."""

    def __init__(self, lines):
        self.rules = []  # (negate, anchored, dir_only, parts)
        for raw in lines:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            neg = line.startswith("!")
            if neg:
                line = line[1:]
            dir_only = line.endswith("/")
            line = line.rstrip("/")
            anchored = line.startswith("/") or "/" in line.lstrip("/")
            if line.startswith("**/"):
                anchored, line = False, line[3:]
            parts = line.lstrip("/").split("/")
            self.rules.append((neg, anchored, dir_only, parts))

    @classmethod
    def load(cls, path):
        return cls(Path(path).read_text().splitlines()) if path and Path(path).exists() else cls([])

    @staticmethod
    def _glob(comps, parts):
        """Match path components against pattern parts, where a part '**' matches any number of components."""
        if not parts:
            return not comps
        head = parts[0]
        if head == "**":
            return any(Rules._glob(comps[i:], parts[1:]) for i in range(len(comps) + 1))
        return bool(comps) and fnmatch.fnmatchcase(comps[0], head) and Rules._glob(comps[1:], parts[1:])

    def excluded(self, rel, is_dir):
        comps = rel.split("/")
        result = False
        for neg, anchored, dir_only, parts in self.rules:
            if dir_only and not is_dir:
                continue
            hit = self._glob(comps, parts) if anchored else (
                len(comps) >= len(parts) and self._glob(comps[-len(parts):], parts))
            if hit:
                result = not neg
        return result


# --------------------------------------------------------------------------------------------------- scanning
def scan(root, rules):
    """Return ({rel: signature}, [unreadable rel dirs/files]). Signatures:
    ('d',) | ('f', size, mtime_ns, mode) | ('l', target). Directory mtimes are deliberately ignored."""
    entries, blind = {}, []
    stack = [""]
    while stack:
        rel = stack.pop()
        try:
            it = os.scandir(os.path.join(root, rel) if rel else root)
        except OSError:
            blind.append(rel)
            continue
        with it:
            for de in it:
                r = f"{rel}/{de.name}" if rel else de.name
                try:
                    st = de.stat(follow_symlinks=False)
                except OSError:
                    blind.append(r)
                    continue
                mode = st.st_mode
                if stat.S_ISDIR(mode):
                    if rules.excluded(r, True):
                        continue
                    entries[r] = ("d",)
                    stack.append(r)
                elif stat.S_ISREG(mode):
                    if not rules.excluded(r, False):
                        entries[r] = ("f", st.st_size, st.st_mtime_ns, stat.S_IMODE(mode))
                elif stat.S_ISLNK(mode):
                    if rules.excluded(r, False):
                        continue
                    try:
                        entries[r] = ("l", os.readlink(os.path.join(root, r)))
                    except OSError:
                        blind.append(r)
                # sockets, fifos and devices are not synced
    return entries, blind


def _ancestors(rel):
    comps = rel.split("/")
    for i in range(1, len(comps) + 1):
        yield "/".join(comps[:i])


def _is_blind(rel, blind):
    return any(a in blind for a in _ancestors(rel))


# ---------------------------------------------------------------------------------------------------- manifest
class Manifest:
    def __init__(self, path):
        Path(path).parent.mkdir(parents=True, exist_ok=True)
        self.db = sqlite3.connect(str(path))
        self.db.execute("CREATE TABLE IF NOT EXISTS entry (path BLOB PRIMARY KEY, a TEXT NOT NULL, b TEXT NOT NULL)")
        self.db.execute("CREATE TABLE IF NOT EXISTS meta (k TEXT PRIMARY KEY, v TEXT)")
        self.db.commit()

    def meta(self, k, default=None):
        row = self.db.execute("SELECT v FROM meta WHERE k=?", (k,)).fetchone()
        return row[0] if row else default

    def set_meta(self, k, v):
        self.db.execute("INSERT OR REPLACE INTO meta VALUES (?,?)", (k, v))

    def load(self):
        out = {}
        for p, a, b in self.db.execute("SELECT path, a, b FROM entry"):
            out[os.fsdecode(p)] = (tuple(json.loads(a)), tuple(json.loads(b)))
        return out

    def upsert(self, rows):
        self.db.executemany("INSERT OR REPLACE INTO entry VALUES (?,?,?)",
                            [(os.fsencode(p), json.dumps(a), json.dumps(b)) for p, a, b in rows])

    def drop(self, paths):
        self.db.executemany("DELETE FROM entry WHERE path=?", [(os.fsencode(p),) for p in paths])

    def clear(self):
        self.db.execute("DELETE FROM entry")

    def commit(self):
        self.db.commit()


# ------------------------------------------------------------------------------------------------------ planning
def same_content(rel, sa, sb, root_a, root_b):
    """True when the two signatures describe the same thing. Same size but different mtime is settled by comparing bytes."""
    if sa[0] != sb[0]:
        return False
    kind = sa[0]
    if kind == "d":
        return True
    if kind == "l":
        return sa[1] == sb[1]
    if sa[1] != sb[1] or sa[3] != sb[3]:  # size, mode
        return False
    if sa[2] == sb[2]:
        return True
    try:
        return filecmp.cmp(os.path.join(root_a, rel), os.path.join(root_b, rel), shallow=False)
    except OSError:
        return False


class Plan:
    def __init__(self):
        self.copy_ab, self.copy_ba = [], []      # (rel, reason) files/symlinks to copy
        self.mkdir_a, self.mkdir_b = [], []      # directories to create
        self.delete_a, self.delete_b = [], []    # (rel, sig) to move to trash (propagating a deletion)
        self.rmdir_a, self.rmdir_b = [], []      # directories to remove if empty
        self.record = []                         # (rel, sa, sb) identical on both sides
        self.drop = []                           # manifest rows for paths gone from both sides
        self.conflicts = []                      # (rel, text) needs a human look (also acted on safely)
        self.skipped = []                        # (rel, text)
        self.blind = []                          # unreadable places


def make_plan(a, b, m, blind_a, blind_b, root_a, root_b):
    ba, bb = set(blind_a), set(blind_b)
    plan = Plan()
    plan.blind = [("A", p) for p in sorted(ba)] + [("B", p) for p in sorted(bb)]
    blocked = set()  # paths whose type differs between the sides: nothing beneath them may be touched
    for rel in sorted(set(a) | set(b) | set(m)):
        if _is_blind(rel, ba) or _is_blind(rel, bb):
            continue
        if any(anc in blocked for anc in list(_ancestors(rel))[:-1]):
            continue
        sa, sb, rec = a.get(rel), b.get(rel), m.get(rel)
        if sa is None and sb is None:
            plan.drop.append(rel)
            continue
        if sa is not None and sb is not None:
            if sa[0] != sb[0]:
                plan.skipped.append((rel, f"type differs ({sa[0]} on A, {sb[0]} on B): it and everything under it are left alone"))
                blocked.add(rel)
                continue
            if same_content(rel, sa, sb, root_a, root_b):
                plan.record.append((rel, sa, sb))
                continue
            changed_a = rec is None or sa != rec[0]
            changed_b = rec is None or sb != rec[1]
            if changed_a and not changed_b:
                plan.copy_ab.append((rel, "changed on A"))
            elif changed_b and not changed_a:
                plan.copy_ba.append((rel, "changed on B"))
            else:  # both changed (or no history): newer wins, the other is kept in the trash
                a_newer = sa[2] >= sb[2]
                why = "conflict, A newer" if a_newer else "conflict, B newer"
                (plan.copy_ab if a_newer else plan.copy_ba).append((rel, why))
                plan.conflicts.append((rel, f"edited on both sides: {'A' if a_newer else 'B'} is newer and wins; the other copy is in the trash"))
            continue
        # present on one side only
        here, there = ("A", "B") if sa is not None else ("B", "A")
        sig = sa if sa is not None else sb
        mine = rec[0] if (rec and sa is not None) else (rec[1] if rec else None)
        copy = plan.copy_ab if sa is not None else plan.copy_ba
        mkdir = plan.mkdir_b if sa is not None else plan.mkdir_a
        if rec is None:
            if sig[0] == "d":
                mkdir.append(rel)
            else:
                copy.append((rel, f"new on {here}"))
        elif sig == mine:                      # known, untouched here: the other side deleted it
            if sig[0] == "d":
                (plan.rmdir_a if here == "A" else plan.rmdir_b).append(rel)
            else:
                (plan.delete_a if here == "A" else plan.delete_b).append((rel, sig))
        else:                                  # deleted there, edited here: keep the edit
            if sig[0] == "d":
                mkdir.append(rel)
            else:
                copy.append((rel, f"edited on {here} after {there} deleted it"))
                plan.conflicts.append((rel, f"deleted on {there} but edited on {here}: kept and copied back"))
    return plan


# ------------------------------------------------------------------------------------------------------ helpers
def fs_identity(root, side):
    """A stable id of the filesystem mounted at root (UUID when findmnt has it). Tests can pin it with SWARM_SYNC_IDENTITY_A/B."""
    override = os.environ.get("SWARM_SYNC_IDENTITY_" + side)
    if override:
        return override
    try:
        out = subprocess.run(["findmnt", "-no", "UUID", "-T", root], capture_output=True, text=True, timeout=10).stdout.strip()
        return out or f"dev:{os.stat(root).st_dev}"
    except Exception:
        return f"dev:{os.stat(root).st_dev}"


def free_bytes(root, side):
    """Free space at root. Tests can pin it with SWARM_SYNC_FREE_A/B."""
    override = os.environ.get("SWARM_SYNC_FREE_" + side)
    if override:
        return int(override)
    return shutil.disk_usage(root).free


def free_margin(root):
    """Space that must stay free after a sync: the larger of 2 GiB and 2% of the filesystem (SWARM_SYNC_FREE_MARGIN pins it)."""
    override = os.environ.get("SWARM_SYNC_FREE_MARGIN")
    if override is not None:
        return int(override)
    return max(2 * 2**30, int(0.02 * shutil.disk_usage(root).total))


def human(n):
    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        if n < 1024 or unit == "TiB":
            return f"{n:.1f} {unit}" if unit != "B" else f"{n} B"
        n /= 1024


def copy_bytes(items, side_map):
    return sum(side_map[rel][1] for rel, _ in items if side_map.get(rel, ("",))[0] == "f")


def build_lock_held(root_b):
    for cand in (os.path.join(root_b, "70-scripts/.swarm-build.lock"), os.path.join(DEFAULT_A, "70-scripts/.swarm-build.lock")):
        if not os.path.exists(cand):
            continue
        try:
            fd = os.open(cand, os.O_RDONLY)
        except OSError:
            continue
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            fcntl.flock(fd, fcntl.LOCK_UN)
        except BlockingIOError:
            return cand
        finally:
            os.close(fd)
    return None


def trash_path(root, run_id, kind, rel):
    return os.path.join(root, TRASH_DIR_NAME, run_id, kind, rel)


def move_to_trash(root, run_id, kind, rel):
    dest = trash_path(root, run_id, kind, rel)
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    os.rename(os.path.join(root, rel), dest)


def run_rsync(src_root, dst_root, rels, backup_dir, log):
    """Copy exactly the listed files/symlinks from src_root to dst_root, keeping the old destination in backup_dir."""
    if not rels:
        return
    with tempfile.NamedTemporaryFile("wb", delete=False) as fh:
        for r in rels:
            fh.write(os.fsencode(r) + b"\0")
        listing = fh.name
    try:
        cmd = ["rsync", "-aHAX", "--no-recursive", "-I", "--from0", f"--files-from={listing}",
               "--backup", f"--backup-dir={backup_dir}", "--suffix=", src_root.rstrip("/") + "/", dst_root.rstrip("/") + "/"]
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode not in (0, 23, 24):
            log(f"rsync exit {res.returncode}: {res.stderr.strip()[:400]}")
        elif res.stderr.strip():
            for line in res.stderr.strip().splitlines()[:20]:
                log("rsync: " + line)
    finally:
        os.unlink(listing)


def prune_trash(root, log):
    base = os.path.join(root, TRASH_DIR_NAME)
    if not os.path.isdir(base):
        return
    runs = sorted(os.listdir(base))
    cutoff = time.time() - KEEP_TRASH_DAYS * 86400
    for name in runs[:-KEEP_TRASH_RUNS]:
        p = os.path.join(base, name)
        try:
            if os.path.getmtime(p) < cutoff:
                shutil.rmtree(p)
                log(f"pruned old trash {p}")
        except OSError as e:
            log(f"could not prune {p}: {e}")


# -------------------------------------------------------------------------------------------------------- main
def summarize(plan, limit, la="Lucy", lb="swarmbuild"):
    def show(title, items, fmt=lambda x: x):
        if not items:
            return
        print(f"\n{title}: {len(items)}")
        for it in items[:limit]:
            print("   ", fmt(it))
        if len(items) > limit:
            print(f"    ... and {len(items) - limit} more (use --list N to see more)")
    show(f"NEW/CHANGED on A ({la}) -> copy to B ({lb})", plan.copy_ab, lambda x: f"{x[0]}   [{x[1]}]")
    show(f"NEW/CHANGED on B ({lb}) -> copy to A ({la})", plan.copy_ba, lambda x: f"{x[0]}   [{x[1]}]")
    show("DELETED on B, so delete on A (to trash)", plan.delete_a, lambda x: x[0])
    show("DELETED on A, so delete on B (to trash)", plan.delete_b, lambda x: x[0])
    show("Folders to create on B", plan.mkdir_b)
    show("Folders to create on A", plan.mkdir_a)
    show("Folders deleted on B, remove on A if empty", plan.rmdir_a)
    show("Folders deleted on A, remove on B if empty", plan.rmdir_b)
    show("NEEDS A LOOK (handled safely)", plan.conflicts, lambda x: f"{x[0]}: {x[1]}")
    show("Left alone", plan.skipped, lambda x: f"{x[0]}: {x[1]}")
    show("Unreadable (nothing under these is touched)", plan.blind, lambda x: f"{x[0]}:{x[1] or '/'}")


def main(argv=None):
    ap = argparse.ArgumentParser(description="Two-way sync of two folders (default /mnt/Lucy and /mnt/swarmbuild) that tells 'created' from 'deleted'.")
    ap.add_argument("--apply", action="store_true", help="do it (default: show the plan only)")
    ap.add_argument("--rebaseline", action="store_true",
                    help="ignore the saved history: treat every difference as new/changed, never as a deletion")
    ap.add_argument("--baseline-delete-b", metavar="FILE",
                    help="FIRST RUN ONLY: a list of paths (one per line, relative) that exist only on B and are really deletions on A "
                         "(e.g. files moved on A before any history existed). They go to B's trash instead of being copied to A.")
    ap.add_argument("--root-a", default=os.environ.get("SWARM_SYNC_ROOT_A", DEFAULT_A))
    ap.add_argument("--root-b", default=os.environ.get("SWARM_SYNC_ROOT_B", DEFAULT_B))
    ap.add_argument("--state-dir", help="where the manifest lives (default: <root-a>/.swarm-sync)")
    ap.add_argument("--rules", default=str(DEFAULT_RULES))
    ap.add_argument("--exclude", action="append", default=[], help="extra exclude pattern (repeatable)")
    ap.add_argument("--max-deletes", type=int, help="refuse to delete more than this many files (default: max(100, 3%% of known files))")
    ap.add_argument("--allow-mass-delete", action="store_true")
    ap.add_argument("--no-mount-check", action="store_true", help="for tests: do not require the roots to be mount points")
    ap.add_argument("--mount-a", help="the mount point root A lives on (when root A is a folder inside it, not the mount itself)")
    ap.add_argument("--mount-b", help="the mount point root B lives on (when root B is a folder inside it, not the mount itself)")
    ap.add_argument("--label-a", default="Lucy", help="name of side A in the plan (default: Lucy)")
    ap.add_argument("--label-b", default="swarmbuild", help="name of side B in the plan (default: swarmbuild)")
    ap.add_argument("--list", type=int, default=15, help="how many paths to list per category")
    args = ap.parse_args(argv)

    root_a, root_b = os.path.abspath(args.root_a), os.path.abspath(args.root_b)
    state = Path(args.state_dir or os.path.join(root_a, STATE_DIR_NAME))
    if not args.no_mount_check:
        for r, mnt in ((root_a, args.mount_a), (root_b, args.mount_b)):
            mnt = os.path.abspath(mnt) if mnt else r
            if not os.path.ismount(mnt):
                print(f"REFUSED: {mnt} is not a mount point (run 70-scripts/check_mounts.sh)", file=sys.stderr)
                return 1
            if r != mnt and os.path.commonpath([r, mnt]) != mnt:
                print(f"REFUSED: {r} is not inside the mount {mnt}", file=sys.stderr)
                return 1
    if not os.path.isdir(root_a) or not os.path.isdir(root_b):
        print("REFUSED: a root directory is missing", file=sys.stderr)
        return 1
    if root_a == root_b:
        print("REFUSED: both roots are the same directory", file=sys.stderr)
        return 1
    held = build_lock_held(root_b)
    if held and not args.no_mount_check:
        print(f"REFUSED: an ISO build holds {held}; sync after it finishes", file=sys.stderr)
        return 1

    state.mkdir(parents=True, exist_ok=True)
    lock_fh = open(state / "sync.lock", "w")
    _open_files.append(lock_fh)
    try:
        fcntl.flock(lock_fh, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        print("REFUSED: another sync is running", file=sys.stderr)
        return 1

    rules = Rules(BUILTIN_RULES)
    rules.rules += Rules.load(args.rules).rules
    rules.rules += Rules(args.exclude).rules
    manifest = Manifest(state / "manifest.sqlite")
    try:
        return _run(args, root_a, root_b, state, rules, manifest)
    finally:
        manifest.db.close()
        while _open_files:
            _open_files.pop().close()


def _run(args, root_a, root_b, state, rules, manifest):

    ident_a, ident_b = fs_identity(root_a, "A"), fs_identity(root_b, "B")
    known = manifest.meta("ident_a")
    if known and not args.rebaseline and (known != ident_a or manifest.meta("ident_b") != ident_b):
        print("REFUSED: a root is not the filesystem this history was made with "
              f"(A {manifest.meta('ident_a')} -> {ident_a}, B {manifest.meta('ident_b')} -> {ident_b}).\n"
              "If a partition was reformatted on purpose, run once with --rebaseline.", file=sys.stderr)
        return 1

    t0 = time.time()
    a, blind_a = scan(root_a, rules)
    b, blind_b = scan(root_b, rules)
    m = {} if args.rebaseline else manifest.load()
    first = not m
    print(f"A {root_a}: {len(a)} entries   B {root_b}: {len(b)} entries   history: {len(m)} entries   (scan {time.time() - t0:.1f}s)")
    if first:
        print("NO HISTORY: this is the first run (or --rebaseline). Differences are treated as new/changed, never as deletions.")

    plan = make_plan(a, b, m, blind_a, blind_b, root_a, root_b)
    if args.baseline_delete_b:
        if not first:
            print("REFUSED: --baseline-delete-b is for the first run (no history) or --rebaseline only; with history, deletions are tracked.", file=sys.stderr)
            return 1
        listed = [ln.rstrip("\n") for ln in Path(args.baseline_delete_b).read_text().splitlines() if ln.strip() and not ln.startswith("#")]
        for rel in listed:
            if rel in b and rel not in a:
                plan.copy_ba = [(r, w) for r, w in plan.copy_ba if r != rel]
                plan.delete_b.append((rel, b[rel]))
            else:
                print(f"note: --baseline-delete-b {rel!r} is not a B-only file; ignored", file=sys.stderr)
    summarize(plan, args.list, args.label_a, args.label_b)
    bytes_ab, bytes_ba = copy_bytes(plan.copy_ab, a), copy_bytes(plan.copy_ba, b)
    print(f"\nData to copy: {human(bytes_ab)} {args.label_a} -> {args.label_b}, {human(bytes_ba)} {args.label_b} -> {args.label_a}")
    for need, dest, side, name in ((bytes_ab, root_b, "B", args.label_b), (bytes_ba, root_a, "A", args.label_a)):
        room = free_bytes(dest, side) - free_margin(dest)
        if need > room:
            print(f"\nREFUSED: {need and human(need)} would be copied to {name} but only {human(max(room, 0))} can be used there "
                  f"(free space minus a safety margin). Nothing was changed. Sync a smaller part (a sub-folder or --exclude) or free space.", file=sys.stderr)
            return 1

    # --- guards against an emptied / unmounted side looking like "everything was deleted"
    n_del = len(plan.delete_a) + len(plan.delete_b)
    limit = args.max_deletes if args.max_deletes is not None else max(100, int(0.03 * max(len(m), 1)))
    if n_del > limit and not args.allow_mass_delete:
        print(f"\nREFUSED: the plan deletes {n_del} files (limit {limit}). If a side is unmounted or emptied that is what it looks like. "
              "Check with 70-scripts/check_mounts.sh; if the deletions are real, re-run with --allow-mass-delete.", file=sys.stderr)
        return 1
    if not first and len(m) > 100 and not args.allow_mass_delete:
        for name, side in (("A", a), ("B", b)):
            if len(side) < 0.5 * len(m):
                print(f"\nREFUSED: side {name} has {len(side)} entries but the history knows {len(m)}; it looks emptied or unmounted.", file=sys.stderr)
                return 1

    actions = (len(plan.copy_ab) + len(plan.copy_ba) + n_del + len(plan.mkdir_a) + len(plan.mkdir_b)
               + len(plan.rmdir_a) + len(plan.rmdir_b))
    if not args.apply:
        print(f"\nDRY RUN: {actions} actions planned, nothing changed. Add --apply to do it.")
        return 2 if plan.conflicts or plan.skipped else 0

    run_id = time.strftime("%Y%m%d-%H%M%S")
    log_dir = state / "runs"
    log_dir.mkdir(exist_ok=True)
    log_fh = open(log_dir / f"{run_id}.log", "w")
    _open_files.append(log_fh)

    def log(msg):
        print(msg)
        log_fh.write(msg + "\n")
        log_fh.flush()

    log(f"run {run_id}: {actions} actions; trash = <root>/{TRASH_DIR_NAME}/{run_id}/")
    failed, touched = [], set()

    def fresh(root, rel, expect):
        try:
            st = os.lstat(os.path.join(root, rel))
        except OSError:
            return False
        cur = ("d",) if stat.S_ISDIR(st.st_mode) else (
            ("l", os.readlink(os.path.join(root, rel))) if stat.S_ISLNK(st.st_mode)
            else ("f", st.st_size, st.st_mtime_ns, stat.S_IMODE(st.st_mode)))
        return cur == expect

    # 1) propagate deletions (old file -> trash)
    for root, items, side in ((root_a, plan.delete_a, "A"), (root_b, plan.delete_b, "B")):
        for rel, sig in items:
            if not fresh(root, rel, sig):
                log(f"skip delete {side}:{rel} (changed since the scan)")
                continue
            try:
                move_to_trash(root, run_id, "deleted", rel)
                touched.add(rel)
                log(f"deleted on {'B' if side == 'A' else 'A'} -> removed from {side}: {rel}")
            except OSError as e:
                failed.append(rel)
                log(f"FAILED to delete {side}:{rel}: {e}")

    # 2) copies. Skip anything that changed since the scan.
    def usable(src_root, items, src_map):
        ok = []
        for rel, why in items:
            if fresh(src_root, rel, src_map[rel]):
                ok.append(rel)
            else:
                log(f"skip copy {rel} (changed since the scan; next run)")
        return ok
    ab = usable(root_a, plan.copy_ab, a)
    ba = usable(root_b, plan.copy_ba, b)
    for rel, why in plan.copy_ab:
        if rel in ab:
            log(f"A -> B  {rel}   [{why}]")
    for rel, why in plan.copy_ba:
        if rel in ba:
            log(f"B -> A  {rel}   [{why}]")
    # an overwritten destination keeps its old content in the trash
    run_rsync(root_a, root_b, ab, os.path.join(root_b, TRASH_DIR_NAME, run_id, "overwritten"), log)
    run_rsync(root_b, root_a, ba, os.path.join(root_a, TRASH_DIR_NAME, run_id, "overwritten"), log)
    touched.update(ab)
    touched.update(ba)

    # 3) folders
    for root, items in ((root_b, plan.mkdir_b), (root_a, plan.mkdir_a)):
        for rel in items:
            try:
                os.makedirs(os.path.join(root, rel), exist_ok=True)
                touched.add(rel)
            except OSError as e:
                failed.append(rel)
                log(f"FAILED to create folder {rel}: {e}")
    for root, items in ((root_a, plan.rmdir_a), (root_b, plan.rmdir_b)):
        for rel in sorted(items, key=lambda p: -p.count("/")):
            try:
                os.rmdir(os.path.join(root, rel))  # only if empty: anything created in it since is kept
                touched.add(rel)
                log(f"removed empty folder {rel}")
            except OSError:
                pass

    # 4) record what is now identical, drop what is gone from both sides
    a2, blind_a2 = scan(root_a, rules)
    b2, blind_b2 = scan(root_b, rules)
    rows, drop = [], list(plan.drop)
    for rel in set(touched) | {r for r, _, _ in plan.record}:
        if _is_blind(rel, set(blind_a2)) or _is_blind(rel, set(blind_b2)):
            continue
        sa, sb = a2.get(rel), b2.get(rel)
        if sa is None and sb is None:
            drop.append(rel)
        elif sa is not None and sb is not None and same_content(rel, sa, sb, root_a, root_b):
            if m.get(rel) != (sa, sb):
                rows.append((rel, sa, sb))
        elif rel in touched:
            failed.append(rel)
            log(f"NOT in sync after the copy: {rel} (will be retried next run)")

    if os.environ.get("SWARM_SYNC_TEST_CRASH") == "before-manifest":
        raise RuntimeError("test crash before the manifest was written")
    if args.rebaseline:
        manifest.clear()
    manifest.upsert(rows)
    manifest.drop(drop)
    manifest.set_meta("ident_a", ident_a)
    manifest.set_meta("ident_b", ident_b)
    manifest.set_meta("last_run", run_id)
    manifest.commit()
    prune_trash(root_a, log)
    prune_trash(root_b, log)
    log(f"done: {len(rows)} records updated, {len(drop)} dropped, {len(failed)} need a retry; log {log_dir / (run_id + '.log')}")
    return 2 if failed or plan.conflicts or plan.skipped else 0


if __name__ == "__main__":
    sys.exit(main())
