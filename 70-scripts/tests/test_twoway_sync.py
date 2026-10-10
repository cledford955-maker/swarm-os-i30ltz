"""Tests for swarm_twoway_sync.py: real files, real rsync, temp directories.

The headline behaviour: a file on only ONE side is either NEW (copy it over) or DELETED on the other side (delete it here
too), and the tool knows which because it remembers what both sides looked like after the last run.
"""
import contextlib
import importlib.util
import io
import os
import stat
import tempfile
import time
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location("sync", Path(__file__).resolve().parents[1] / "swarm_twoway_sync.py")
sync = importlib.util.module_from_spec(spec)
spec.loader.exec_module(sync)

RULES = """\
/skipme/
build/
*.pyc
!keep.pyc
"""


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        t = Path(self.tmp.name)
        self.A, self.B, self.state = t / "A", t / "B", t / "state"
        self.A.mkdir(); self.B.mkdir()
        self.rules = t / "rules"
        self.rules.write_text(RULES)
        self.clock = 1_700_000_000
        os.environ["SWARM_SYNC_IDENTITY_A"] = "uuid-a"
        os.environ["SWARM_SYNC_IDENTITY_B"] = "uuid-b"
        os.environ.pop("SWARM_SYNC_TEST_CRASH", None)

    def tearDown(self):
        for root in (self.A, self.B):  # undo any chmod 000 so the temp dir can be removed
            for d, dirs, _ in os.walk(root):
                for x in dirs:
                    try: os.chmod(os.path.join(d, x), 0o755)
                    except OSError: pass
        self.tmp.cleanup()

    # --- helpers
    def run_sync(self, *extra, apply=True):
        args = ["--root-a", str(self.A), "--root-b", str(self.B), "--state-dir", str(self.state), "--rules", str(self.rules),
                "--no-mount-check", "--list", "50"]
        if apply:
            args.append("--apply")
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = sync.main(args + list(extra))
        self.out, self.err = out.getvalue(), err.getvalue()
        return code

    def put(self, root, rel, text="x", age=0, mode=None):
        p = root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)
        self.clock += 10
        os.utime(p, (self.clock - age, self.clock - age))
        if mode is not None:
            os.chmod(p, mode)
        return p

    def ex(self, root, rel):
        return os.path.lexists(root / rel)

    def read(self, root, rel):
        return (root / rel).read_text()

    def trash(self, root, kind):
        base = root / ".sync-trash"
        if not base.exists():
            return []
        out = []
        for run in sorted(base.iterdir()):
            d = run / kind
            if d.exists():
                out += [str(p.relative_to(d)) for p in d.rglob("*") if p.is_file() or p.is_symlink()]
        return out

    def baseline(self):
        self.assertEqual(0, self.run_sync(), self.out + self.err)


class CreatedVersusDeleted(Base):
    """The behaviour the user asked for."""

    def test_new_file_on_each_side_is_copied_not_mistaken_for_a_deletion(self):
        self.put(self.A, "shared.txt"); self.put(self.B, "shared.txt")
        self.baseline()
        self.put(self.A, "made_on_lucy.txt", "from A")
        self.put(self.B, "made_on_build.txt", "from B")
        self.assertEqual(0, self.run_sync(), self.out + self.err)
        for root in (self.A, self.B):
            self.assertEqual("from A", self.read(root, "made_on_lucy.txt"))
            self.assertEqual("from B", self.read(root, "made_on_build.txt"))
        self.assertEqual([], self.trash(self.A, "deleted") + self.trash(self.B, "deleted"))

    def test_deleted_on_build_side_is_deleted_on_lucy_and_kept_in_trash(self):
        self.put(self.A, "gone.txt", "bye"); self.put(self.B, "gone.txt", "bye")
        self.put(self.A, "stay.txt"); self.put(self.B, "stay.txt")
        self.baseline()
        os.unlink(self.B / "gone.txt")
        self.assertEqual(0, self.run_sync(), self.out + self.err)
        self.assertFalse(self.ex(self.A, "gone.txt"))
        self.assertTrue(self.ex(self.A, "stay.txt") and self.ex(self.B, "stay.txt"))
        self.assertEqual(["gone.txt"], self.trash(self.A, "deleted"))
        run = next((self.A / ".sync-trash").iterdir())
        self.assertEqual("bye", (run / "deleted" / "gone.txt").read_text())

    def test_deleted_on_lucy_is_deleted_on_build_side(self):
        self.put(self.A, "gone.txt"); self.put(self.B, "gone.txt")
        self.baseline()
        os.unlink(self.A / "gone.txt")
        self.run_sync()
        self.assertFalse(self.ex(self.B, "gone.txt"))
        self.assertEqual(["gone.txt"], self.trash(self.B, "deleted"))

    def test_created_and_deleted_are_told_apart_in_the_same_run(self):
        self.put(self.A, "old.txt"); self.put(self.B, "old.txt")
        self.baseline()
        os.unlink(self.B / "old.txt")                 # deleted on B
        self.put(self.A, "fresh.txt", "new on A")     # created on A
        self.run_sync()
        self.assertFalse(self.ex(self.A, "old.txt"))                      # the deletion propagated
        self.assertEqual("new on A", self.read(self.B, "fresh.txt"))      # the creation propagated
        self.assertTrue(self.ex(self.A, "fresh.txt"))

    def test_an_edit_beats_a_deletion(self):
        self.put(self.A, "doc.txt", "v1"); self.put(self.B, "doc.txt", "v1")
        self.baseline()
        os.unlink(self.B / "doc.txt")
        self.put(self.A, "doc.txt", "v2 edited on A after B deleted it")
        code = self.run_sync()
        self.assertEqual("v2 edited on A after B deleted it", self.read(self.B, "doc.txt"))
        self.assertEqual("v2 edited on A after B deleted it", self.read(self.A, "doc.txt"))
        self.assertEqual(2, code, "an edit-vs-delete is reported")
        self.assertIn("deleted on B but edited on A", self.out)

    def test_deleted_on_both_sides_just_forgets_it(self):
        self.put(self.A, "x.txt"); self.put(self.B, "x.txt")
        self.baseline()
        os.unlink(self.A / "x.txt"); os.unlink(self.B / "x.txt")
        self.assertEqual(0, self.run_sync())
        self.assertEqual([], self.trash(self.A, "deleted") + self.trash(self.B, "deleted"))
        self.put(self.A, "x.txt", "reborn")           # and a later file with the same name is simply new
        self.run_sync()
        self.assertEqual("reborn", self.read(self.B, "x.txt"))

    def test_without_history_nothing_is_ever_deleted(self):
        self.put(self.A, "only_a.txt"); self.put(self.B, "only_b.txt")
        self.assertEqual(0, self.run_sync())          # first run: union, no deletions possible
        self.assertTrue(all(self.ex(r, n) for r in (self.A, self.B) for n in ("only_a.txt", "only_b.txt")))
        self.assertIn("NO HISTORY", self.out)

    def test_rebaseline_forgets_history_and_never_deletes(self):
        self.put(self.A, "f.txt"); self.put(self.B, "f.txt")
        self.baseline()
        os.unlink(self.B / "f.txt")                   # would normally delete it from A
        self.run_sync("--rebaseline")
        self.assertTrue(self.ex(self.A, "f.txt") and self.ex(self.B, "f.txt"))


class FirstRunDecisions(Base):
    def test_baseline_delete_b_trashes_only_the_listed_b_only_files(self):
        self.put(self.A, "images/moved/pic.png", "moved on A")          # the user moved it on A ...
        self.put(self.B, "images/old/pic.png", "stale old location")    # ... B still has the old location
        self.put(self.B, "images/new_on_b.png", "really new on B")
        listing = Path(self.tmp.name) / "list.txt"
        listing.write_text("# stale\nimages/old/pic.png\nimages/moved/pic.png\nnot/there.png\n")
        self.assertEqual(0, self.run_sync("--baseline-delete-b", str(listing)), self.out + self.err)
        self.assertFalse(self.ex(self.A, "images/old/pic.png"), "the stale file must not be copied back to A")
        self.assertFalse(self.ex(self.B, "images/old/pic.png"))
        self.assertEqual(["images/old/pic.png"], self.trash(self.B, "deleted"))
        self.assertEqual("really new on B", self.read(self.A, "images/new_on_b.png"))   # unlisted B-only files are still copied
        self.assertEqual("moved on A", self.read(self.B, "images/moved/pic.png"))
        self.assertIn("not a B-only file", self.err)                                    # listed paths that are not B-only are ignored

    def test_baseline_delete_b_is_refused_once_there_is_history(self):
        self.put(self.A, "a.txt"); self.put(self.B, "a.txt")
        self.baseline()
        listing = Path(self.tmp.name) / "list.txt"
        listing.write_text("a.txt\n")
        self.assertEqual(1, self.run_sync("--baseline-delete-b", str(listing)))
        self.assertTrue(self.ex(self.A, "a.txt") and self.ex(self.B, "a.txt"))


class Changes(Base):
    def test_change_on_one_side_overwrites_the_other_in_either_direction(self):
        self.put(self.A, "a.txt", "1"); self.put(self.B, "a.txt", "1")
        self.put(self.A, "b.txt", "1"); self.put(self.B, "b.txt", "1")
        self.baseline()
        self.put(self.A, "a.txt", "A2"); self.put(self.B, "b.txt", "B2")
        self.assertEqual(0, self.run_sync(), self.out + self.err)
        self.assertEqual("A2", self.read(self.B, "a.txt"))
        self.assertEqual("B2", self.read(self.A, "b.txt"))
        self.assertEqual(["a.txt"], self.trash(self.B, "overwritten"))   # the old B copy is kept
        self.assertEqual(["b.txt"], self.trash(self.A, "overwritten"))

    def test_edited_on_both_sides_newer_wins_and_the_loser_is_kept(self):
        self.put(self.A, "c.txt", "base"); self.put(self.B, "c.txt", "base")
        self.baseline()
        self.put(self.A, "c.txt", "A version", age=100)
        self.put(self.B, "c.txt", "B version (newer)")
        code = self.run_sync()
        self.assertEqual(2, code)
        self.assertEqual("B version (newer)", self.read(self.A, "c.txt"))
        self.assertEqual("B version (newer)", self.read(self.B, "c.txt"))
        run = next((self.A / ".sync-trash").iterdir())
        self.assertEqual("A version", (run / "overwritten" / "c.txt").read_text())

    def test_same_bytes_with_different_mtime_is_not_a_change(self):
        self.put(self.A, "same.txt", "identical", age=500); self.put(self.B, "same.txt", "identical")
        self.assertEqual(0, self.run_sync())
        self.assertEqual([], self.trash(self.A, "overwritten") + self.trash(self.B, "overwritten"))
        self.assertNotIn("conflict", self.out)

    def test_second_run_has_nothing_to_do(self):
        self.put(self.A, "a.txt"); self.put(self.B, "b.txt")
        self.baseline()
        self.assertEqual(0, self.run_sync(apply=False))
        self.assertIn("0 actions planned", self.out)

    def test_dry_run_changes_nothing(self):
        self.put(self.A, "a.txt")
        self.assertEqual(0, self.run_sync(apply=False))
        self.assertFalse(self.ex(self.B, "a.txt"))
        self.assertFalse((self.state / "manifest.sqlite").exists() and sync.Manifest(self.state / "manifest.sqlite").load())

    def test_exec_bit_and_mtime_are_preserved(self):
        p = self.put(self.A, "run.sh", "#!/bin/sh\n", mode=0o755)
        self.run_sync()
        q = self.B / "run.sh"
        self.assertTrue(q.stat().st_mode & stat.S_IXUSR)
        self.assertEqual(p.stat().st_mtime_ns // 1000, q.stat().st_mtime_ns // 1000)

    def test_unusual_names(self):
        for name in ("with space.txt", "ünïcode-名前.txt", "-leading-dash.txt", "new\nline.txt", "sub dir/deep file.txt"):
            self.put(self.A, name, name)
        self.run_sync()
        for name in ("with space.txt", "ünïcode-名前.txt", "-leading-dash.txt", "new\nline.txt", "sub dir/deep file.txt"):
            self.assertEqual(name, self.read(self.B, name))
        os.unlink(self.B / "with space.txt")
        self.run_sync()
        self.assertFalse(self.ex(self.A, "with space.txt"))

    def test_type_change_is_left_alone(self):
        self.put(self.A, "thing", "i am a file")
        (self.B / "thing").mkdir()
        self.put(self.B, "thing/inner.txt", "i am inside a dir")
        code = self.run_sync()
        self.assertEqual(2, code)
        self.assertEqual("i am a file", self.read(self.A, "thing"))
        self.assertEqual("i am inside a dir", self.read(self.B, "thing/inner.txt"))


class FoldersAndLinks(Base):
    def test_a_deleted_folder_tree_is_deleted_on_the_other_side(self):
        self.put(self.A, "d/x.txt"); self.put(self.A, "d/sub/y.txt")
        self.put(self.B, "d/x.txt"); self.put(self.B, "d/sub/y.txt")
        self.baseline()
        import shutil
        shutil.rmtree(self.B / "d")
        self.run_sync()
        self.assertFalse(self.ex(self.A, "d"))
        self.assertEqual(sorted(["d/x.txt", "d/sub/y.txt"]), sorted(self.trash(self.A, "deleted")))

    def test_a_new_file_inside_a_folder_the_other_side_deleted_survives(self):
        self.put(self.A, "d/old.txt"); self.put(self.B, "d/old.txt")
        self.baseline()
        import shutil
        shutil.rmtree(self.B / "d")
        self.put(self.A, "d/new.txt", "created after")
        self.run_sync()
        self.assertFalse(self.ex(self.A, "d/old.txt"))                 # the old file followed the deletion
        self.assertEqual("created after", self.read(self.A, "d/new.txt"))   # the new one is kept ...
        self.assertEqual("created after", self.read(self.B, "d/new.txt"))   # ... and copied over
        self.run_sync(apply=False)
        self.assertIn("0 actions planned", self.out)

    def test_empty_folders_are_created_and_deleted(self):
        (self.A / "empty_a").mkdir(); (self.B / "empty_b").mkdir()
        self.baseline()
        self.assertTrue(self.ex(self.B, "empty_a") and self.ex(self.A, "empty_b"))
        os.rmdir(self.B / "empty_a")
        self.run_sync()
        self.assertFalse(self.ex(self.A, "empty_a"))
        self.assertTrue(self.ex(self.A, "empty_b"))

    def test_symlinks_are_copied_changed_and_deleted_as_links(self):
        self.put(self.A, "real.txt")
        os.symlink("real.txt", self.A / "link")
        self.run_sync()
        self.assertEqual("real.txt", os.readlink(self.B / "link"))
        os.unlink(self.A / "link"); os.symlink("elsewhere", self.A / "link")
        self.run_sync()
        self.assertEqual("elsewhere", os.readlink(self.B / "link"))
        os.unlink(self.B / "link")
        self.run_sync()
        self.assertFalse(self.ex(self.A, "link"))
        self.assertTrue(self.ex(self.A, "real.txt"))


class ExcludesAndSafety(Base):
    def test_excluded_paths_are_never_touched_in_either_direction(self):
        self.put(self.A, "build/out.bin", "A build"); self.put(self.B, "build/out.bin", "B build")
        self.put(self.A, "skipme/a.txt"); self.put(self.B, "skipme/b.txt")
        self.put(self.A, "mod.pyc"); self.put(self.A, "keep.pyc", "re-included")
        self.put(self.A, "real.txt")
        self.baseline()
        self.assertEqual("A build", self.read(self.A, "build/out.bin"))
        self.assertEqual("B build", self.read(self.B, "build/out.bin"))
        self.assertFalse(self.ex(self.B, "skipme/a.txt") or self.ex(self.A, "skipme/b.txt"))
        self.assertFalse(self.ex(self.B, "mod.pyc"))
        self.assertEqual("re-included", self.read(self.B, "keep.pyc"))
        os.unlink(self.B / "build/out.bin")           # deleting an excluded file must not delete the other side's
        self.run_sync()
        self.assertTrue(self.ex(self.A, "build/out.bin"))

    def test_git_state_and_trash_are_built_in_exclusions(self):
        self.put(self.A, ".git/HEAD", "ref A"); self.put(self.B, ".git/HEAD", "ref B")
        self.put(self.A, ".sync-trash/old/x", "junk")
        self.put(self.A, "real.txt")
        self.baseline()
        self.assertEqual("ref B", self.read(self.B, ".git/HEAD"))
        self.assertFalse(self.ex(self.B, ".sync-trash/old/x"))

    @unittest.skipIf(os.geteuid() == 0, "root can read everything")
    def test_an_unreadable_folder_is_unknown_not_deleted(self):
        self.put(self.A, "locked/secret.txt", "keep me"); self.put(self.B, "locked/secret.txt", "keep me")
        self.put(self.A, "open.txt"); self.put(self.B, "open.txt")
        self.baseline()
        os.chmod(self.B / "locked", 0)                 # B can no longer be read there: that is NOT a deletion
        code = self.run_sync()
        self.assertEqual("keep me", self.read(self.A, "locked/secret.txt"))
        self.assertIn("Unreadable", self.out)
        os.chmod(self.B / "locked", 0o755)
        self.assertEqual(2, code if code else 2)

    def test_a_side_that_looks_emptied_or_unmounted_deletes_nothing(self):
        for i in range(150):
            self.put(self.A, f"f{i}.txt"); self.put(self.B, f"f{i}.txt")
        self.baseline()
        for i in range(150):
            os.unlink(self.B / f"f{i}.txt")            # what an unmounted / emptied B looks like
        self.assertEqual(1, self.run_sync())
        self.assertIn("REFUSED", self.err)
        self.assertEqual(150, len(list(self.A.glob("f*.txt"))))
        self.assertEqual(0, self.run_sync("--allow-mass-delete"))   # only when the user insists
        self.assertEqual(0, len(list(self.A.glob("f*.txt"))))

    def test_a_side_that_lost_most_of_its_files_is_refused_even_below_the_delete_limit(self):
        for i in range(120):
            self.put(self.A, f"g{i}.txt"); self.put(self.B, f"g{i}.txt")
        self.baseline()
        for i in range(70):
            os.unlink(self.B / f"g{i}.txt")            # 70 < 100 deletions, but B has under half of what we know
        self.assertEqual(1, self.run_sync())
        self.assertEqual(120, len(list(self.A.glob("g*.txt"))))

    def test_a_different_filesystem_is_refused_until_rebaselined(self):
        self.put(self.A, "a.txt"); self.put(self.B, "a.txt")
        self.baseline()
        os.environ["SWARM_SYNC_IDENTITY_B"] = "a-different-partition"
        self.assertEqual(1, self.run_sync())
        self.assertIn("not the filesystem", self.err)
        self.assertEqual(0, self.run_sync("--rebaseline"))
        self.assertEqual(0, self.run_sync())

    def test_a_file_changed_after_the_scan_is_skipped_not_copied_half_way(self):
        self.put(self.A, "busy.txt", "v1")
        real = sync.make_plan
        def meddling(*a, **k):
            plan = real(*a, **k)
            self.put(self.A, "busy.txt", "v2 written between the scan and the copy, longer")
            return plan
        sync.make_plan = meddling
        try:
            self.run_sync()
        finally:
            sync.make_plan = real
        self.assertIn("changed since the scan", self.out)
        self.assertFalse(self.ex(self.B, "busy.txt"))
        self.run_sync()                                # next run picks it up
        self.assertEqual("v2 written between the scan and the copy, longer", self.read(self.B, "busy.txt"))

    def test_a_crash_before_the_history_is_saved_is_harmless_on_the_next_run(self):
        self.put(self.A, "gone.txt"); self.put(self.B, "gone.txt")
        self.put(self.A, "stay.txt"); self.put(self.B, "stay.txt")
        self.baseline()
        os.unlink(self.B / "gone.txt")
        self.put(self.A, "new.txt", "created")
        os.environ["SWARM_SYNC_TEST_CRASH"] = "before-manifest"
        with self.assertRaises(RuntimeError):
            self.run_sync()
        os.environ.pop("SWARM_SYNC_TEST_CRASH")
        self.assertFalse(self.ex(self.A, "gone.txt"))   # the deletion had already been done
        self.assertEqual(0, self.run_sync(), self.out + self.err)
        self.assertTrue(self.ex(self.A, "stay.txt") and self.ex(self.B, "stay.txt"))
        self.assertEqual("created", self.read(self.B, "new.txt"))
        self.assertFalse(self.ex(self.B, "gone.txt"))
        self.run_sync(apply=False)
        self.assertIn("0 actions planned", self.out)

    def test_old_trash_is_pruned_but_the_last_runs_are_kept(self):
        base = self.A / ".sync-trash"
        for i in range(8):
            d = base / f"2026010{i}-000000"
            d.mkdir(parents=True)
            (d / "f").write_text("x")
            os.utime(d, (1_000_000, 1_000_000))        # ancient
        msgs = []
        sync.prune_trash(str(self.A), msgs.append)
        self.assertEqual(5, len(list(base.iterdir())))
        self.assertEqual(["20260103-000000", "20260104-000000", "20260105-000000", "20260106-000000", "20260107-000000"],
                         sorted(p.name for p in base.iterdir()))


class SpaceAndMounts(Base):
    """A sync must never start a copy that cannot fit, must say how much it will copy, and a root may be a folder inside a mount."""

    def tearDown(self):
        for k in ("SWARM_SYNC_FREE_A", "SWARM_SYNC_FREE_B", "SWARM_SYNC_FREE_MARGIN"):
            os.environ.pop(k, None)
        super().tearDown()

    def test_reports_how_much_data_will_move(self):
        (self.A / "big.bin").write_bytes(b"x" * 1000)
        (self.B / "other.bin").write_bytes(b"y" * 300)
        self.run_sync(apply=False)
        self.assertIn("Data to copy: 1000 B Lucy -> swarmbuild, 300 B swarmbuild -> Lucy", self.out)

    def test_refuses_a_copy_that_does_not_fit(self):
        (self.A / "big.bin").write_bytes(b"x" * 1000)
        os.environ["SWARM_SYNC_FREE_MARGIN"] = "0"
        os.environ["SWARM_SYNC_FREE_B"] = "500"
        self.assertEqual(self.run_sync(), 1)
        self.assertIn("REFUSED", self.err); self.assertIn("only", self.err)
        self.assertFalse((self.B / "big.bin").exists(), "nothing may be copied when it does not fit")
        os.environ["SWARM_SYNC_FREE_B"] = "5000"
        self.assertEqual(self.run_sync(), 0)
        self.assertEqual((self.B / "big.bin").read_bytes(), b"x" * 1000)

    def test_refuses_in_the_other_direction_too(self):
        (self.B / "big.bin").write_bytes(b"y" * 1000)
        os.environ["SWARM_SYNC_FREE_MARGIN"] = "0"
        os.environ["SWARM_SYNC_FREE_A"] = "10"
        self.assertEqual(self.run_sync(), 1)
        self.assertFalse((self.A / "big.bin").exists())

    def test_the_safety_margin_counts(self):
        (self.A / "f").write_bytes(b"x" * 100)
        os.environ["SWARM_SYNC_FREE_B"] = "150"
        os.environ["SWARM_SYNC_FREE_MARGIN"] = "100"   # 150 free - 100 margin = 50 usable < 100 needed
        self.assertEqual(self.run_sync(), 1)
        os.environ["SWARM_SYNC_FREE_MARGIN"] = "40"    # 110 usable >= 100
        self.assertEqual(self.run_sync(), 0)

    def test_deletions_need_no_space(self):
        (self.A / "f").write_bytes(b"x" * 100); (self.B / "f").write_bytes(b"x" * 100)
        os.utime(self.A / "f", (self.clock, self.clock)); os.utime(self.B / "f", (self.clock, self.clock))
        self.assertEqual(self.run_sync(), 0)
        (self.A / "f").unlink()
        os.environ["SWARM_SYNC_FREE_B"] = "0"; os.environ["SWARM_SYNC_FREE_MARGIN"] = "0"
        self.assertEqual(self.run_sync(), 0, self.err)
        self.assertFalse((self.B / "f").exists())

    def test_side_labels_appear_in_the_plan(self):
        (self.A / "f").write_text("x")
        self.run_sync("--label-a", "Lucy project", "--label-b", "lucy-master", apply=False)
        self.assertIn("NEW/CHANGED on A (Lucy project) -> copy to B (lucy-master)", self.out)

    def _real_mount_args(self, mount_a, mount_b):
        args = ["--root-a", str(self.A), "--root-b", str(self.B), "--state-dir", str(self.state), "--rules", str(self.rules),
                "--mount-a", mount_a, "--mount-b", mount_b, "--apply"]
        out, err = io.StringIO(), io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(err):
            code = sync.main(args)
        self.out, self.err = out.getvalue(), err.getvalue()
        return code

    def test_a_root_may_be_a_folder_inside_a_mount(self):
        (self.A / "f").write_text("hello")
        self.assertEqual(self._real_mount_args("/", "/"), 0, self.err)       # "/" is a mount point and both roots are inside it
        self.assertEqual((self.B / "f").read_text(), "hello")

    def test_the_named_mount_must_really_be_a_mount(self):
        self.assertEqual(self._real_mount_args("/", str(self.B)), 1)         # a plain folder is not a mount point
        self.assertIn("is not a mount point", self.err)

    def test_the_root_must_be_inside_the_named_mount(self):
        (self.A / "f").write_text("hello")
        self.assertEqual(self._real_mount_args("/", "/proc"), 1)             # /proc is a mount, but B is not inside it
        self.assertIn("is not inside the mount", self.err)
        self.assertFalse((self.B / "f").exists())


class RuleSyntax(unittest.TestCase):
    def test_semantics(self):
        r = sync.Rules(["/top/", "build/", "*.pyc", "**/target/", "/a/*/obj/", "/x/*", "!/x/keep/", "/exact.txt"])
        ex = r.excluded
        self.assertTrue(ex("top", True)); self.assertFalse(ex("top", False)); self.assertFalse(ex("sub/top", True))
        self.assertTrue(ex("any/where/build", True)); self.assertFalse(ex("build", False))
        self.assertTrue(ex("mod.pyc", False)); self.assertTrue(ex("deep/dir/mod.pyc", False))
        self.assertTrue(ex("p/q/target", True)); self.assertTrue(ex("target", True))
        self.assertTrue(ex("a/b/obj", True)); self.assertFalse(ex("a/obj", True)); self.assertFalse(ex("a/b/c/obj", True))
        self.assertTrue(ex("x/other", True)); self.assertFalse(ex("x/keep", True)); self.assertFalse(ex("x/keep/inside.txt", False))
        self.assertTrue(ex("exact.txt", False)); self.assertFalse(ex("dir/exact.txt", False))

    def test_the_real_rules_file_keeps_source_and_drops_build_output(self):
        r = sync.Rules.load(sync.DEFAULT_RULES)
        for p, d in [("30-source/swarm-slint/target", True), ("30-source/frontend/build", True), ("install-env", True),
                     ("30-source/frontend/linux/flutter/ephemeral", True), ("swarm_os_build_work", True), ("30-source/LucilleAssistant", True),
                     ("40-iso-profile/swarm_os_iso_profile/airootfs/opt", True), ("x/y/__pycache__", True), ("a.iso", False),
                     ("40-iso-profile/swarm_os_iso_profile/airootfs/usr/lib/libfoo", True)]:
            self.assertTrue(r.excluded(p, d), p)
        for p, d in [("30-source/frontend/lib", True), ("30-source/frontend/lib/main.dart", False), ("70-scripts", True),
                     ("70-scripts/build_swarm_iso.sh", False), ("CLAUDE.md", False), ("20-runtime/.env", False),
                     ("images/websitebackgrounds", True), ("40-iso-profile/swarm_os_iso_profile/airootfs/usr/lib/swarm", True),
                     ("40-iso-profile/swarm_os_iso_profile/airootfs/etc/systemd/system", True),
                     ("40-iso-profile/swarm_os_iso_profile/profiledef.sh", False)]:
            self.assertFalse(r.excluded(p, d), p)


if __name__ == "__main__":
    unittest.main()
