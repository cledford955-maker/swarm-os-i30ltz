#!/usr/bin/env python3
"""Collapse byte-identical duplicate files listed in a dupscan report.

    dedupe_archive.py REPORT                       dry run (default, changes nothing, fast)
    dedupe_archive.py REPORT --hardlink            replace duplicates with hardlinks
    dedupe_archive.py REPORT --delete              remove duplicates, keep one copy
    options: --root /mnt/archive  --only PREFIX (repeatable)  --verbose

REPORT is the "## <size> bytes x N copies" / one-path-per-line file written by
the duplicate scan. Per set the KEEPER is the oldest file (mtime), ties broken
by shortest path. Every other copy is byte-compared against the keeper
(filecmp, not the scan's hash) immediately before it is touched.

--hardlink is the right mode for snapshot trees (swarm_versions/*, system
backups): every path stays valid, the space is freed, and nothing is lost. It
needs the same filesystem and identical mode/uid/gid, and is done as
link-to-temp-name + rename, so a failure leaves the original file in place.
--delete removes the extra copies - only use it where a missing path is fine.
Neither mode ever removes the keeper, crosses a filesystem, or follows a symlink.
"""
import argparse
import filecmp
import os
import stat
import sys


def parse(report):
    sets, cur = [], None
    with open(report) as fh:
        for line in fh:
            line = line.rstrip("\n")
            if line.startswith("## "):
                cur = []
                sets.append(cur)
            elif cur is not None and line.startswith("/"):
                cur.append(line)
    return [s for s in sets if len(s) > 1]


def lstat_reg(p):
    try:
        st = os.lstat(p)
    except OSError:
        return None
    return st if stat.S_ISREG(st.st_mode) else None


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("report")
    ap.add_argument("--root", default="/mnt/archive", help="refuse to touch anything outside this directory")
    ap.add_argument("--only", action="append", default=[], metavar="PREFIX",
                    help="only act on copies under this path prefix (keeper may be anywhere under --root)")
    mode = ap.add_mutually_exclusive_group()
    mode.add_argument("--hardlink", action="store_true")
    mode.add_argument("--delete", action="store_true")
    ap.add_argument("--dry-run", action="store_true",
                    help="preview only (implied when no mode is given; previews hardlink rules). "
                         "Skips the byte-compare, so it is fast but unverified.")
    ap.add_argument("--verbose", "-v", action="store_true")
    ap.add_argument("--max-errors", type=int, default=20)
    a = ap.parse_args()

    root = os.path.realpath(a.root)
    dry = a.dry_run or not (a.hardlink or a.delete)
    if not dry and os.statvfs(root).f_flag & os.ST_RDONLY:
        sys.exit(f"{root} is mounted read-only; nothing was changed.\n"
                 f"Remount it read-write first:  sudo mount -o remount,rw {root}\n"
                 f"and back afterwards:          sudo mount -o remount,ro {root}")
    rules = "delete" if a.delete else "hardlink"      # which constraints apply
    act = "dry-run" if dry else rules
    done = skipped = errors = 0
    freed = 0
    skip_reasons = {}

    def skip(why, p):
        nonlocal skipped
        skipped += 1
        skip_reasons[why] = skip_reasons.get(why, 0) + 1
        if a.verbose:
            print(f"skip ({why}): {p}")

    for paths in parse(a.report):
        live = []
        for p in paths:
            if not os.path.realpath(os.path.dirname(p)).startswith(root + os.sep):
                skip("outside-root", p)
                continue
            st = lstat_reg(p)
            if st is not None:
                live.append((st.st_mtime, len(p), p, st))
        if len(live) < 2:
            continue
        live.sort(key=lambda t: (t[0], t[1], t[2]))
        _, _, keeper, kst = live[0]
        for _, _, p, st in live[1:]:
            if a.only and not any(p.startswith(x) for x in a.only):
                continue
            if (st.st_dev, st.st_ino) == (kst.st_dev, kst.st_ino):
                skip("already-same-inode", p)
                continue
            if st.st_dev != kst.st_dev:
                skip("different-filesystem", p)
                continue
            if st.st_size != kst.st_size:
                skip("size-changed", p)
                continue
            if rules == "hardlink" and (st.st_mode, st.st_uid, st.st_gid) != (kst.st_mode, kst.st_uid, kst.st_gid):
                skip("mode-or-owner-differs", p)
                continue
            try:
                if not dry and not filecmp.cmp(keeper, p, shallow=False):
                    skip("content-differs", p)
                    continue
                if a.verbose:
                    print(f"{act}: {p}  <-  {keeper}")
                if act == "hardlink":
                    tmp = f"{p}.dedupe-tmp-{os.getpid()}"
                    try:
                        os.link(keeper, tmp)
                        os.replace(tmp, p)
                    except OSError:
                        try:
                            os.unlink(tmp)
                        except OSError:
                            pass
                        raise
                elif act == "delete":
                    os.unlink(p)
                done += 1
                freed += st.st_size
            except OSError as e:
                errors += 1
                print(f"ERROR {p}: {e}", file=sys.stderr)
                if errors >= a.max_errors:
                    print("too many errors, stopping", file=sys.stderr)
                    summary(act, done, skipped, errors, freed, skip_reasons)
                    return 1
    summary(act, done, skipped, errors, freed, skip_reasons)
    return 1 if errors else 0


def summary(act, done, skipped, errors, freed, reasons):
    verb = {"dry-run": "would change", "hardlink": "hardlinked", "delete": "deleted"}[act]
    print(f"{act}: {verb} {done} files, {freed / 2**30:.1f} GiB freed; skipped {skipped}, errors {errors}")
    for k, v in sorted(reasons.items(), key=lambda kv: -kv[1]):
        print(f"  skipped {v:6d}  {k}")
    if act == "dry-run":
        print("nothing was changed (dry run; contents not re-compared - the real run byte-compares every copy first)")


if __name__ == "__main__":
    sys.exit(main())
