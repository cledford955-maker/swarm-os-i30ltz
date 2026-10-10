"""Secure Boot preflight: the trust-chain verdict, tested on layouts built from REAL signed/unsigned boot files.
Skips when the Debian signed packages or the SWARM kernel are not present on this machine."""
import importlib.util
import os
import shutil
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location("pre", Path(__file__).resolve().parents[1] / "secureboot_preflight.py")
pre = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pre)

SHIM = "/usr/lib/shim/shimx64.efi.signed"
GRUB = "/usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed"
DEB_KERNELS = sorted(str(p) for p in Path("/boot").glob("vmlinuz-*"))
ARCH_KERNEL = "/mnt/swarm/@/boot/vmlinuz-linux"
HAVE = all(os.path.exists(p) for p in (SHIM, GRUB)) and DEB_KERNELS and shutil.which("openssl")
# Same shape as this machine's firmware db: Microsoft's UEFI CA is in it, Debian's key is not.
DB = {"CN=Microsoft Corporation UEFI CA 2011, O=Microsoft Corporation, C=US": {}}


@unittest.skipUnless(HAVE, "needs Debian's signed shim/grub/kernel and openssl on this machine")
class Verdicts(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        self.db = pre.firmware_report.__globals__["cert_names"] and self._real_db()

    def tearDown(self):
        self.tmp.cleanup()

    def _real_db(self):
        # use the firmware's real db when readable (this machine); otherwise fall back to the Microsoft-only stand-in
        data = pre.efivar("db", pre.GUID_DB)
        if data:
            return {n["subject"]: n for n in (pre.cert_names(c) for c in pre.x509_certs_from_siglist(data))}
        return DB

    def put(self, rel, src):
        p = self.root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy(src, p)
        return str(p)

    def test_debian_style_chain_is_bootable_with_secure_boot_on(self):
        files = [self.put("EFI/debian/shimx64.efi", SHIM), self.put("EFI/debian/grubx64.efi", GRUB),
                 self.put("EFI/BOOT/BOOTX64.EFI", SHIM), self.put("boot/vmlinuz-6.12", DEB_KERNELS[-1])]
        res, problems = pre.os_verdict(files, self.db)
        self.assertEqual([], problems)
        self.assertEqual(pre.FW, res[files[0]][0])        # the firmware accepts the Microsoft-signed shim
        self.assertEqual(pre.DEBIAN, res[files[1]][0])    # Debian's grub is accepted by the shim, not by the firmware
        self.assertEqual(pre.DEBIAN, res[files[3]][0])

    @unittest.skipUnless(os.path.exists(ARCH_KERNEL), "needs the installed SWARM kernel")
    def test_arch_style_unsigned_chain_is_refused(self):
        files = [self.put("EFI/SWARM_OS/grubx64.efi", ARCH_KERNEL),   # any unsigned PE image stands in for Arch's GRUB
                 self.put("boot/vmlinuz-linux", ARCH_KERNEL)]
        res, problems = pre.os_verdict(files, self.db)
        self.assertTrue(problems)
        self.assertEqual(pre.UNSIGNED, res[files[1]][0])
        self.assertTrue(any("nothing the firmware itself would start" in p for p in problems))

    @unittest.skipUnless(os.path.exists(ARCH_KERNEL), "needs the installed SWARM kernel")
    def test_a_good_shim_does_not_rescue_an_unsigned_grub_or_kernel(self):
        files = [self.put("EFI/debian/shimx64.efi", SHIM), self.put("EFI/debian/grubx64.efi", ARCH_KERNEL),
                 self.put("boot/vmlinuz-linux", ARCH_KERNEL)]
        _res, problems = pre.os_verdict(files, self.db)
        self.assertEqual(2, len([p for p in problems if "UNSIGNED" in p]))

    def test_debian_signed_files_without_a_shim_are_not_enough(self):
        files = [self.put("EFI/debian/grubx64.efi", GRUB), self.put("boot/vmlinuz-6.12", DEB_KERNELS[-1])]
        _res, problems = pre.os_verdict(files, self.db)
        self.assertTrue(problems, "GRUB signed only by Debian's key cannot be started by the firmware without shim")

    def test_non_efi_files_are_ignored_and_pe_parsing_is_safe(self):
        junk = self.root / "EFI/x/notefi.efi"
        junk.parent.mkdir(parents=True)
        junk.write_bytes(b"MZ" + b"\0" * 10)                   # truncated / malformed PE
        self.assertIn(pre.judge(str(junk), self.db)[0], (pre.NOTPE, pre.UNSIGNED))
        self.assertEqual(pre.NOTPE, pre.judge("/usr/bin/ls", self.db)[0])
        self.assertEqual(pre.NOTPE, pre.judge("/no/such/file", self.db)[0])


class LuksParsing(unittest.TestCase):
    LUKS2 = """LUKS header information
Version:        2
Epoch:          7
Metadata area:  16384 [bytes]

Data segments:
  0: crypt
	offset: 16777216 [bytes]

Keyslots:
  0: luks2
	Key:        512 bits
	PBKDF:      argon2id
  1: luks2
	Key:        512 bits
Tokens:
  0: systemd-tpm2
	tpm2-hash-pcrs:   7
Digests:
  0: pbkdf2
	Hash:       sha256
"""
    LUKS2_NO_TOKENS = LUKS2.replace("  0: systemd-tpm2\n\ttpm2-hash-pcrs:   7\n", "")
    LUKS1 = """LUKS header information for /dev/sdx
Version:        1
Key Slot 0: ENABLED
Key Slot 1: DISABLED
Key Slot 2: ENABLED
"""

    def test_luks2_with_a_tpm_token(self):
        self.assertEqual({"version": 2, "keyslots": 2, "tokens": ["systemd-tpm2"]}, pre.parse_luks_dump(self.LUKS2))

    def test_luks2_without_tokens(self):
        self.assertEqual({"version": 2, "keyslots": 2, "tokens": []}, pre.parse_luks_dump(self.LUKS2_NO_TOKENS))

    def test_luks1_counts_enabled_slots_only(self):
        self.assertEqual({"version": 1, "keyslots": 2, "tokens": []}, pre.parse_luks_dump(self.LUKS1))

    def test_garbage_does_not_crash(self):
        self.assertEqual({"version": 0, "keyslots": 0, "tokens": []}, pre.parse_luks_dump("not a luks dump"))
        self.assertEqual(0, pre.parse_luks_dump("")["keyslots"])


class BootEntries(unittest.TestCase):
    # The real `efibootmgr -v` lines from this machine (2026-10-10).
    REAL = """BootCurrent: 0003
Timeout: 2 seconds
BootOrder: 0003,0000,0004,0005,001F
Boot0000* SWARM_OS\tHD(1,GPT,41cd2e0e-92fe-4300-9d8d-f37ad7f486d7,0x800,0x41a000)/File(\\EFI\\SWARM_OS\\grubx64.efi)
      dp: 04 01 2a 00 01 00 00 00 00 08 00 00 00 00 00 00 00 a0 41 00
Boot0001* I30LTZ Recovery OS\tHD(1,GPT,e25e5715-f3b8-4ddb-9796-d1c270804140,0x800,0x200000)/File(\\EFI\\i30ltz\\grubx64.efi)
Boot0003* debian\tHD(1,GPT,c2da7f22-db73-4cc3-b73f-6446fa6aad3d,0x800,0x219800)/File(\\EFI\\debian\\shimx64.efi)
Boot0010  Setup\tFvFile(721c8b66-426c-4e86-8e99-3457c46ab0b9)
Boot001F* UEFI: PXE IPv4\tPciRoot(0x0)/Pci(0x1,0x0)/MAC(001122334455,1)/IPv4(0.0.0.0)
"""

    def test_parses_only_entries_that_start_a_file_on_a_gpt_partition(self):
        e = pre.parse_boot_entries(self.REAL)
        self.assertEqual(["0000", "0001", "0003"], [x["num"] for x in e])
        self.assertEqual("I30LTZ Recovery OS", e[1]["label"])
        self.assertEqual("\\EFI\\i30ltz\\grubx64.efi", e[1]["file"])
        self.assertEqual("e25e5715-f3b8-4ddb-9796-d1c270804140", e[1]["partuuid"])

    def test_an_entry_that_starts_debians_grub_directly_fails_but_the_shim_entry_is_fine(self):
        root = self.make_esp()
        roots = {"e25e5715-f3b8-4ddb-9796-d1c270804140": root}
        grub = {"num": "0001", "label": "x", "partuuid": "e25e5715-f3b8-4ddb-9796-d1c270804140", "file": "\\EFI\\i30ltz\\grubx64.efi"}
        shim = dict(grub, file="\\EFI\\i30ltz\\shimx64.efi")
        gone = dict(grub, file="\\EFI\\nope\\x.efi")
        other = dict(grub, partuuid="00000000-0000-0000-0000-000000000000")
        db = TestDb.db()
        self.assertEqual("FAIL", pre.judge_entry(grub, roots, db)[0])
        self.assertIn("shim", pre.judge_entry(grub, roots, db)[1])
        self.assertEqual("ok", pre.judge_entry(shim, roots, db)[0])
        self.assertEqual("missing", pre.judge_entry(gone, roots, db)[0])
        self.assertEqual("unknown", pre.judge_entry(other, roots, db)[0])

    def test_fat_paths_are_case_insensitive(self):
        root = self.make_esp(shim_name="SHIMX64.EFI")
        e = {"num": "1", "label": "x", "partuuid": "p", "file": "\\EFI\\i30ltz\\shimx64.efi"}
        self.assertEqual("ok", pre.judge_entry(e, {"p": root}, TestDb.db())[0])

    def make_esp(self, shim_name="shimx64.efi"):
        d = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, d, True)
        os.makedirs(os.path.join(d, "EFI/i30ltz"))
        shutil.copy(SHIM, os.path.join(d, "EFI/i30ltz", shim_name))
        shutil.copy(GRUB, os.path.join(d, "EFI/i30ltz/grubx64.efi"))
        return d


class TestDb:
    @staticmethod
    def db():
        data = pre.efivar("db", pre.GUID_DB)
        if data:
            return {n["subject"]: n for n in (pre.cert_names(c) for c in pre.x509_certs_from_siglist(data))}
        return DB


if __name__ == "__main__":
    unittest.main()
