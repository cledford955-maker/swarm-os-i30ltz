#!/usr/bin/env python3
"""Tests for the swarm-grub theme: build output, GRUB-readability of every asset, installer round trip.

    cd swarm-grub/tests && python3 -m unittest -v test_swarm_grub

Nothing here needs root or touches the real boot setup: the installer runs with --stage in a scratch dir.
"""
import re
import shutil
import struct
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent
SLICES = ("nw", "n", "ne", "w", "c", "e", "sw", "s", "se")
# Every --class the menu can carry that needs an icon: Debian's own entries, the SWARM/Recovery/Ventoy
# entries from grub_themes/09_swarm_debian, the Power & firmware submenu and os-prober's Arch entries.
REQUIRED_CLASSES = {"debian", "gnu-linux", "gnu", "linux", "swarm_os", "recovery_os", "ventoy", "tools",
                    "restart", "shutdown", "efi", "arch", "unknown"}


def png_info(path):
    data = Path(path).read_bytes()
    assert data[:8] == b"\x89PNG\r\n\x1a\n", f"{path}: not a PNG"
    width, height, depth, ctype, _comp, _filt, interlace = struct.unpack(">IIBBBBB", data[16:29])
    return {"w": width, "h": height, "depth": depth, "ctype": ctype, "interlace": interlace}


def pf2_sections(path):
    data = Path(path).read_bytes()
    assert data[:4] == b"FILE" and data[8:12] == b"PFF2", f"{path}: not a PF2 font"
    pos, out = 12, {}
    while pos + 8 <= len(data):
        tag = data[pos:pos + 4].decode("latin1")
        (length,) = struct.unpack(">I", data[pos + 4:pos + 8])
        out[tag] = data[pos + 8:pos + 8 + length] if tag != "DATA" else b""
        pos += 8 + length
        if tag == "DATA":
            break
    return out


class BuildTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = Path(tempfile.mkdtemp(prefix="swarm-grub-test-"))
        cls.out = cls.tmp / "theme"
        res = subprocess.run(["bash", str(ROOT / "build.sh"), str(cls.out)], capture_output=True, text=True)
        assert res.returncode == 0, res.stderr

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def test_background_is_a_plain_png_of_the_right_size(self):
        info = png_info(self.out / "background.png")
        self.assertEqual((info["w"], info["h"]), (1920, 1080))
        self.assertEqual(info["depth"], 8)
        self.assertEqual(info["interlace"], 0, "GRUB cannot read interlaced PNGs")
        self.assertLess((self.out / "background.png").stat().st_size, 3_500_000, "slow to load in GRUB")

    def test_icons_are_64px_8bit_not_interlaced(self):
        icons = sorted((self.out / "icons").glob("*.png"))
        self.assertGreaterEqual(len(icons), 15)
        for icon in icons:
            info = png_info(icon)
            self.assertEqual((info["w"], info["h"], info["depth"], info["interlace"]), (64, 64, 8, 0), icon.name)

    def test_every_menu_class_has_an_icon(self):
        have = {p.stem for p in (self.out / "icons").glob("*.png")}
        self.assertEqual(REQUIRED_CLASSES - have, set())
        used = set(re.findall(r"--class ([A-Za-z0-9_-]+)", (ROOT / "entries" / "20_swarm_entries").read_text()))
        self.assertTrue({"swarm_os", "recovery_os", "ventoy", "tools", "restart", "shutdown"} <= used)
        self.assertEqual(used - have, set(), "the entries script uses a class with no icon")

    def test_console_backdrop_is_small_and_readable_by_grub(self):
        info = png_info(self.out / "terminal_bg.png")
        self.assertEqual((info["w"], info["h"], info["depth"], info["interlace"]), (480, 270, 8, 0))
        self.assertLess((self.out / "terminal_bg.png").stat().st_size, 100_000)

    def test_ventoy_icon_exists_in_svg_and_png(self):
        self.assertTrue((ROOT / "icons" / "ventoy.svg").exists())
        self.assertEqual(png_info(self.out / "icons" / "ventoy.png")["w"], 64)

    def test_nine_slice_pixmaps_have_the_right_geometry(self):
        for prefix, r in (("select", 8), ("item", 8), ("terminal_box", 6)):
            want = {"nw": (r, r), "n": (1, r), "ne": (r, r), "w": (r, 1), "c": (1, 1),
                    "e": (r, 1), "sw": (r, r), "s": (1, r), "se": (r, r)}
            for name in SLICES:
                info = png_info(self.out / f"{prefix}_{name}.png")
                self.assertEqual((info["w"], info["h"]), want[name], f"{prefix}_{name}")

    def test_selected_and_plain_rows_share_padding(self):
        for name in SLICES:   # otherwise the highlighted row shifts by the difference
            a, b = png_info(self.out / f"select_{name}.png"), png_info(self.out / f"item_{name}.png")
            self.assertEqual((a["w"], a["h"]), (b["w"], b["h"]), name)

    def test_fonts_are_valid_for_grub(self):
        fonts = sorted(self.out.glob("*.pf2"))
        self.assertGreaterEqual(len(fonts), 5)
        for font in fonts:
            chix = pf2_sections(font)["CHIX"]
            codes = [struct.unpack(">I", chix[i:i + 4])[0] for i in range(0, len(chix), 9)]
            self.assertTrue(codes, font.name)
            # GRUB refuses a font whose character table is not strictly ascending ("not in ascending order")
            self.assertEqual(codes, sorted(set(codes)), f"{font.name}: characters not strictly ascending")

    def test_theme_txt_is_complete_and_self_consistent(self):
        text = (self.out / "theme.txt").read_text(encoding="utf-8")
        self.assertNotIn("@FONT_", text)
        names = {pf2_sections(f)["NAME"].rstrip(b"\0").decode() for f in self.out.glob("*.pf2")}
        for font in re.findall(r'font(?:-font)?\s*[:=]\s*"([^"]+)"', text) + re.findall(r'terminal-font: "([^"]+)"', text):
            self.assertIn(font, names, f"theme.txt uses font {font!r} that no .pf2 provides")
        for ref in re.findall(r'"([^"]+\.png)"', text):
            if "*" in ref:
                for name in SLICES:
                    self.assertTrue((self.out / ref.replace("*", name)).exists(), ref)
            else:
                self.assertTrue((self.out / ref).exists(), ref)
        self.assertIn('id = "__timeout__"', text)
        self.assertNotIn("@TIMEOUT_NOTIFICATION", text, "labels need a %d template, not the progress-bar tokens")

    def test_menu_sits_inside_the_painted_panel(self):
        svg = (ROOT / "background.svg").read_text()
        panel = re.search(r'<rect x="([\d.]+)" y="([\d.]+)" width="([\d.]+)" height="([\d.]+)"[^>]*fill="url\(#panelFill\)"', svg)
        self.assertIsNotNone(panel)
        px, py, pw, ph = (float(v) for v in panel.groups())
        menu = {k: int(v) for k, v in re.findall(r"^\s+(left|top|width|height) = (\d+)%", (ROOT / "theme.txt.in").read_text()
                                                  .split("+ boot_menu")[1].split("}")[0], re.M)}
        left, top = menu["left"] / 100 * 1920, menu["top"] / 100 * 1080
        right, bottom = left + menu["width"] / 100 * 1920, top + menu["height"] / 100 * 1080
        for edge, inside in ((left - px, left >= px + 20), (px + pw - right, right <= px + pw - 20),
                             (top - py, top >= py + 20), (py + ph - bottom, bottom <= py + ph - 20)):
            self.assertTrue(inside, f"boot_menu is too close to the panel edge ({edge:.0f}px)")


class EntriesTests(unittest.TestCase):
    SCRIPT = ROOT / "entries" / "20_swarm_entries"

    def generated(self):
        return subprocess.run(["sh", str(self.SCRIPT)], capture_output=True, text=True, check=True).stdout

    def test_script_is_valid_shell_and_valid_grub(self):
        self.assertEqual(subprocess.run(["sh", "-n", str(self.SCRIPT)]).returncode, 0)
        if shutil.which("grub-script-check"):   # GRUB has no && or ||: only its own parser can say
            with tempfile.NamedTemporaryFile("w", suffix=".cfg") as fh:
                fh.write(self.generated())
                fh.flush()
                res = subprocess.run(["grub-script-check", fh.name], capture_output=True, text=True)
                self.assertEqual(res.returncode, 0, res.stderr)

    def test_entries_ids_and_order(self):
        out = self.generated()
        ids = re.findall(r"--id (swarm-[a-z]+)", out)
        self.assertEqual(ids[:4], ["swarm-swarmos", "swarm-recovery", "swarm-ventoy", "swarm-power"])
        self.assertTrue(out.startswith("# swarm-grub boot entries"), "install.sh recognises its own script by this line")

    def test_each_os_is_found_by_the_documented_efi_partition(self):
        out = self.generated()
        for name, uuid, first in (("SWARM OS", "FE19-A70F", "/EFI/SWARM_OS/grubx64.efi"),
                                  ("Recovery OS", "A367-87E3", "/EFI/i30ltz/shimx64.efi"),
                                  ("Ventoy", "626B-4255", "/EFI/BOOT/BOOTX64.EFI")):
            self.assertRegex(out, rf"swarm_find_esp '{name}' {uuid}")
            self.assertRegex(out, rf"swarm_chain '{name}' {re.escape(first)}")
        self.assertIn("VTOYEFI", out)
        self.assertNotRegex(out, r"(?i)cachy|ef9acba2", "CachyOS is decommissioned")
        self.assertNotIn("362A-E48F", out, "Recovery OS no longer shares Debian's ESP")

    def test_script_uses_no_grub_operators_it_cannot_parse(self):
        body = self.generated()
        self.assertNotRegex(body, r"\|\||&&")


class InstallerTests(unittest.TestCase):
    STOCK = ('GRUB_DEFAULT=0\nGRUB_TIMEOUT=5\nGRUB_CMDLINE_LINUX_DEFAULT="quiet"\n'
             '# comment\n#GRUB_TERMINAL=console\n')

    def run_install(self, stage, *args):
        return subprocess.run(["bash", str(ROOT / "install.sh"), "--stage", str(stage), *args],
                              capture_output=True, text=True)

    def stage(self, seed):
        tmp = Path(tempfile.mkdtemp(prefix="swarm-grub-stage-"))
        self.addCleanup(shutil.rmtree, tmp, ignore_errors=True)
        (tmp / "etc/default").mkdir(parents=True)
        (tmp / "etc/default/grub").write_text(seed)
        return tmp

    def test_install_is_idempotent_and_uninstall_restores_byte_for_byte(self):
        stage = self.stage(self.STOCK)
        for _ in range(2):
            res = self.run_install(stage)
            self.assertEqual(res.returncode, 0, res.stdout + res.stderr)
        cfg = (stage / "etc/default/grub").read_text()
        self.assertEqual(cfg.count("# BEGIN SWARM-GRUB THEME"), 1)
        self.assertEqual(cfg.count("# END SWARM-GRUB THEME"), 1)
        self.assertIn('GRUB_THEME="/boot/grub/themes/swarm-grub/theme.txt"', cfg)
        self.assertIn('GRUB_TERMINAL_OUTPUT="gfxterm"', cfg)
        self.assertIn('GRUB_BACKGROUND="/boot/grub/themes/swarm-grub/terminal_bg.png"', cfg)
        self.assertTrue(cfg.startswith(self.STOCK), "existing settings must stay untouched")
        theme = stage / "boot/grub/themes/swarm-grub"
        self.assertTrue((theme / "theme.txt").exists() and (theme / "icons/ventoy.png").exists())
        self.assertGreaterEqual(len(list((stage / "var/backups/swarm-grub").iterdir())), 2)

        res = self.run_install(stage, "--uninstall")
        self.assertEqual(res.returncode, 0, res.stdout + res.stderr)
        self.assertEqual((stage / "etc/default/grub").read_text(), self.STOCK)
        self.assertFalse(theme.exists())

    def test_entries_install_disable_osprober_and_uninstall_cleanly(self):
        stage = self.stage(self.STOCK)
        res = self.run_install(stage, "--with-entries")
        self.assertEqual(res.returncode, 0, res.stdout + res.stderr)
        dst = stage / "etc/grub.d/20_swarm_entries"
        self.assertTrue(dst.exists() and dst.stat().st_mode & 0o111, "entries script must be installed executable")
        self.assertEqual(dst.read_bytes(), (ROOT / "entries/20_swarm_entries").read_bytes())
        cfg = (stage / "etc/default/grub").read_text()
        self.assertIn("GRUB_DISABLE_OS_PROBER=true", cfg)
        # a later plain install keeps the entries (and the os-prober setting that goes with them)
        self.assertEqual(self.run_install(stage).returncode, 0)
        self.assertTrue(dst.exists())
        self.assertIn("GRUB_DISABLE_OS_PROBER=true", (stage / "etc/default/grub").read_text())
        # --without-entries drops them but keeps the theme
        self.assertEqual(self.run_install(stage, "--without-entries").returncode, 0)
        self.assertFalse(dst.exists())
        self.assertNotIn("GRUB_DISABLE_OS_PROBER", (stage / "etc/default/grub").read_text())
        self.assertTrue((stage / "boot/grub/themes/swarm-grub/theme.txt").exists())
        # full round trip back to the untouched file
        self.assertEqual(self.run_install(stage, "--with-entries").returncode, 0)
        res = self.run_install(stage, "--uninstall")
        self.assertEqual(res.returncode, 0, res.stdout + res.stderr)
        self.assertEqual((stage / "etc/default/grub").read_text(), self.STOCK)
        self.assertFalse(dst.exists())

    def test_a_foreign_entries_script_is_never_overwritten_or_removed(self):
        stage = self.stage(self.STOCK)
        (stage / "etc/grub.d").mkdir(parents=True)
        foreign = stage / "etc/grub.d/20_swarm_entries"
        foreign.write_text("#!/bin/sh\n# somebody else's script\n")
        res = self.run_install(stage, "--with-entries")
        self.assertNotEqual(res.returncode, 0)
        self.assertIn("not ours", res.stdout + res.stderr)
        self.assertEqual(foreign.read_text(), "#!/bin/sh\n# somebody else's script\n")
        self.assertEqual(self.run_install(stage, "--uninstall").returncode, 0)
        self.assertTrue(foreign.exists())

    def test_file_without_trailing_newline_still_gets_a_clean_block(self):
        stage = self.stage("GRUB_TIMEOUT=5")
        self.assertEqual(self.run_install(stage).returncode, 0)
        lines = (stage / "etc/default/grub").read_text().splitlines()
        self.assertEqual(lines[0], "GRUB_TIMEOUT=5")
        self.assertTrue(lines[1].startswith("# BEGIN SWARM-GRUB THEME"))

    def test_uninstall_without_install_is_harmless(self):
        stage = self.stage(self.STOCK)
        res = self.run_install(stage, "--uninstall")
        self.assertEqual(res.returncode, 0, res.stdout + res.stderr)
        self.assertEqual((stage / "etc/default/grub").read_text(), self.STOCK)

    def test_bad_argument_is_rejected(self):
        res = subprocess.run(["bash", str(ROOT / "install.sh"), "--nope"], capture_output=True, text=True)
        self.assertEqual(res.returncode, 2)

    def test_dry_run_changes_nothing(self):
        before = Path("/etc/default/grub").read_bytes()
        res = subprocess.run(["bash", str(ROOT / "install.sh"), "--dry-run"], capture_output=True, text=True)
        self.assertEqual(res.returncode, 0, res.stdout + res.stderr)
        self.assertIn("rehearsal only", res.stdout)
        self.assertEqual(Path("/etc/default/grub").read_bytes(), before)
        self.assertFalse(Path("/boot/grub/themes/swarm-grub").exists())


if __name__ == "__main__":
    unittest.main()
