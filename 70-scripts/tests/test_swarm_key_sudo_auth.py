"""Tests for swarm-key-sudo-auth (the SWARM hardware sudo key helper).

Run: cd 70-scripts/tests && python3 -m unittest test_swarm_key_sudo_auth
Uses a regular file as the "device" and a stub udevadm; touches no real disks.
"""
import hashlib
import importlib.machinery
import importlib.util
import os
import pathlib
import stat
import tempfile
import time
import unittest

HELPER = (pathlib.Path(__file__).resolve().parents[2]
          / "40-iso-profile/swarm_os_iso_profile/airootfs/usr/lib/swarm/swarm-key-sudo-auth")
_loader = importlib.machinery.SourceFileLoader("swarm_key_sudo_auth", str(HELPER))
_spec = importlib.util.spec_from_loader(_loader.name, _loader)
helper = importlib.util.module_from_spec(_spec)
_loader.exec_module(helper)

PARTUUID = "3f2b8c1e-5d4a-4e7b-9a60-1c2d3e4f5a6b"
HWSERIAL = "3664251034070005592"
SECRET = "ab" * 32  # 64 hex chars
RECORD = ("SWK1:%s\n" % SECRET).encode()


class KeyHelperTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.d = pathlib.Path(self.tmp.name)
        self.partdir = self.d / "by-partuuid"
        self.partdir.mkdir()
        self.dev = self.d / "sdc1"
        self.dev.write_bytes(RECORD + b"\0" * 1000)
        os.symlink(self.dev, self.partdir / PARTUUID)
        self.udev_bus, self.udev_serial, self.udev_pu = "usb", HWSERIAL, PARTUUID
        self.registry = self.d / "sudo_key.conf"
        self.write_registry()
        self.write_udevadm()

    def tearDown(self):
        self.tmp.cleanup()

    def write_registry(self, sha=None, mode=0o600, partuuid=PARTUUID, serial=HWSERIAL):
        sha = sha or hashlib.sha256(SECRET.encode()).hexdigest()
        self.registry.write_text(
            "KEY_SERIAL=SWK-TEST\nPARTUUID=%s\nHWSERIAL=%s\nSECRET_SHA256=%s\n" % (partuuid, serial, sha))
        os.chmod(self.registry, mode)

    def write_udevadm(self):
        stub = self.d / "udevadm"
        stub.write_text("#!/bin/sh\necho ID_BUS=%s\necho ID_SERIAL_SHORT=%s\necho ID_PART_ENTRY_UUID=%s\n"
                        % (self.udev_bus, self.udev_serial, self.udev_pu))
        stub.chmod(0o755)
        self.stub = str(stub)

    def check(self, **kw):
        args = dict(registry=str(self.registry), partuuid_dir=str(self.partdir),
                    udevadm=self.stub, require_block=False, require_root=False)
        args.update(kw)
        return helper.verify(**args)

    def test_genuine_key_accepted(self):
        self.assertTrue(self.check())

    def test_wrong_secret_rejected(self):
        self.dev.write_bytes(("SWK1:%s\n" % ("cd" * 32)).encode() + b"\0" * 100)
        self.assertFalse(self.check())

    def test_registry_hash_mismatch_rejected(self):
        self.write_registry(sha="0" * 64)
        self.assertFalse(self.check())

    def test_blank_or_short_device_rejected(self):
        self.dev.write_bytes(b"\0" * 200)
        self.assertFalse(self.check())
        self.dev.write_bytes(RECORD[:30])
        self.assertFalse(self.check())

    def test_malformed_record_rejected(self):
        for bad in (b"SWK2:" + SECRET.encode() + b"\n",
                    b"SWK1:" + SECRET.upper().encode() + b"\n",
                    b"SWK1:" + SECRET.encode() + b"X"):
            self.dev.write_bytes(bad + b"\0" * 100)
            self.assertFalse(self.check(), bad)

    def test_device_absent_rejected(self):
        os.unlink(self.partdir / PARTUUID)
        self.assertFalse(self.check())

    def test_not_a_block_device_rejected_in_production_mode(self):
        self.assertFalse(self.check(require_block=True))

    def test_wrong_bus_serial_or_partuuid_rejected(self):
        for attr, val in (("udev_bus", "ata"), ("udev_serial", "OTHER"),
                          ("udev_pu", "00000000-0000-4000-8000-000000000000")):
            setattr(self, attr, val)
            self.write_udevadm()
            self.assertFalse(self.check(), attr)
            self.udev_bus, self.udev_serial, self.udev_pu = "usb", HWSERIAL, PARTUUID
            self.write_udevadm()

    def test_registry_must_be_private(self):
        self.write_registry(mode=0o644)
        self.assertFalse(self.check())
        self.write_registry(mode=0o660)
        self.assertFalse(self.check())

    def test_registry_missing_or_malformed_rejected(self):
        self.registry.unlink()
        self.assertFalse(self.check())
        self.registry.write_text("PARTUUID=not-a-uuid\n")
        os.chmod(self.registry, 0o600)
        self.assertFalse(self.check())

    def test_symlinked_registry_rejected(self):
        real = self.d / "real.conf"
        real.write_text(self.registry.read_text())
        os.chmod(real, 0o600)
        self.registry.unlink()
        os.symlink(real, self.registry)
        self.assertFalse(self.check())

    def test_requires_root_in_production_mode(self):
        if os.geteuid() != 0:
            self.assertFalse(self.check(require_root=True))

    def test_hanging_device_times_out(self):
        os.unlink(self.partdir / PARTUUID)
        fifo = self.d / "fifo"
        os.mkfifo(fifo)  # opening a FIFO with no writer blocks forever
        os.symlink(fifo, self.partdir / PARTUUID)
        t = time.time()
        self.assertFalse(self.check())
        self.assertLess(time.time() - t, helper.TIMEOUT_S + 2)

    def test_entry_point_refuses_outside_sudo_pam(self):
        for env in ({}, {"PAM_TYPE": "auth", "PAM_SERVICE": "login"},
                    {"PAM_TYPE": "account", "PAM_SERVICE": "sudo"}):
            old = {k: os.environ.pop(k, None) for k in ("PAM_TYPE", "PAM_SERVICE")}
            os.environ.update(env)
            try:
                self.assertEqual(helper.main(), 1)
            finally:
                for k in ("PAM_TYPE", "PAM_SERVICE"):
                    os.environ.pop(k, None)
                    if old[k] is not None:
                        os.environ[k] = old[k]

    def test_helper_file_is_executable_python_with_isolated_mode(self):
        self.assertTrue(HELPER.read_text().startswith("#!/usr/bin/python3 -I\n"))


if __name__ == "__main__":
    unittest.main()
