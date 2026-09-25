import importlib.util
import io
import json
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "swarm_workspace_parity.py"
SPEC = importlib.util.spec_from_file_location("swarm_workspace_parity", SCRIPT)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
sys.modules[SPEC.name] = MODULE
SPEC.loader.exec_module(MODULE)


class WorkspaceParityTests(unittest.TestCase):
    def test_reports_bidirectional_drift_and_changed_content(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / "source"
            mirror = root / "mirror"
            source.mkdir()
            mirror.mkdir()
            (source / "same.txt").write_text("same")
            (mirror / "same.txt").write_text("same")
            (source / "changed.txt").write_text("new")
            (mirror / "changed.txt").write_text("old")
            (source / "source-only.txt").write_text("source")
            (mirror / "mirror-only.txt").write_text("mirror")

            report = MODULE.compare(
                MODULE.build_manifest(source, MODULE.DEFAULT_EXCLUDES),
                MODULE.build_manifest(mirror, MODULE.DEFAULT_EXCLUDES),
            )

            self.assertFalse(report["in_sync"])
            self.assertEqual(report["changed"], ["changed.txt"])
            self.assertEqual(report["only_source"], ["source-only.txt"])
            self.assertEqual(report["only_mirror"], ["mirror-only.txt"])

    def test_excludes_secrets_build_outputs_and_does_not_follow_symlinks(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / "source"
            outside = root / "outside"
            source.mkdir()
            outside.mkdir()
            (source / "20-runtime").mkdir()
            (source / "20-runtime" / ".env").write_text("secret")
            (source / "build").mkdir()
            (source / "build" / "binary").write_text("generated")
            (outside / "private").write_text("outside")
            (source / "link").symlink_to(outside / "private")

            manifest = MODULE.build_manifest(source, MODULE.DEFAULT_EXCLUDES)

            self.assertEqual(set(manifest), {"link"})
            self.assertEqual(manifest["link"].kind, "symlink")

    def test_cli_writes_private_manifests_and_returns_drift(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / "source"
            mirror = root / "mirror"
            output = root / "output"
            source.mkdir()
            mirror.mkdir()
            (source / "file").write_text("a")
            (mirror / "file").write_text("b")

            with redirect_stdout(io.StringIO()):
                status = MODULE.main([
                    "--source", str(source),
                    "--mirror", str(mirror),
                    "--manifest-dir", str(output),
                    "--json",
                ])

            self.assertEqual(status, 1)
            report = json.loads((output / "report.json").read_text())
            self.assertEqual(report["status"], "drift")
            self.assertEqual(report["changed"], ["file"])
            self.assertEqual((output / "report.json").stat().st_mode & 0o777, 0o600)

    def test_missing_mirror_can_be_an_explicit_clean_skip(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / "source"
            source.mkdir()
            with redirect_stdout(io.StringIO()):
                status = MODULE.main([
                    "--source", str(source),
                    "--mirror", str(root / "missing"),
                    "--skip-missing",
                    "--json",
                ])
            self.assertEqual(status, 0)

    def test_require_mounts_skips_plain_directories(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / "source"
            mirror = root / "mirror"
            source.mkdir()
            mirror.mkdir()
            with redirect_stdout(io.StringIO()) as output:
                status = MODULE.main([
                    "--source", str(source),
                    "--mirror", str(mirror),
                    "--skip-missing",
                    "--require-mounts",
                    "--json",
                ])
            self.assertEqual(status, 0)
            self.assertEqual(json.loads(output.getvalue())["status"], "skipped")


if __name__ == "__main__":
    unittest.main()
