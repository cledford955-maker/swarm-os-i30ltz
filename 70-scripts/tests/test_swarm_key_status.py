"""Tests for swarm-key-status (publishes key presence for the lock screen).
Run: cd 70-scripts/tests && python3 -m unittest test_swarm_key_status
"""
import hashlib, importlib.machinery, importlib.util, json, os, pathlib, tempfile, unittest
from test_swarm_key_sudo_auth import HELPER, helper, PARTUUID, HWSERIAL, SECRET, RECORD

STATUS = HELPER.parent / "swarm-key-status"
_l = importlib.machinery.SourceFileLoader("swarm_key_status", str(STATUS))
_s = importlib.util.spec_from_loader(_l.name, _l)
status = importlib.util.module_from_spec(_s)
_l.exec_module(status)


class StatusTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        d = self.d = pathlib.Path(self.tmp.name)
        (d / "parts").mkdir(); (d / "keys.d").mkdir(); os.chmod(d / "keys.d", 0o755)
        dev = d / "dev"; dev.write_bytes(RECORD + b"\0" * 100)
        os.symlink(dev, d / "parts" / PARTUUID)
        u = d / "udevadm"
        u.write_text("#!/bin/sh\necho ID_BUS=usb\necho ID_SERIAL_SHORT=%s\necho ID_PART_ENTRY_UUID=%s\n" % (HWSERIAL, PARTUUID))
        u.chmod(0o755)
        c = d / "keys.d" / "SWK-ABC.conf"
        c.write_text("PARTUUID=%s\nHWSERIAL=%s\nSECRET_SHA256=%s\n" % (PARTUUID, HWSERIAL, hashlib.sha256(SECRET.encode()).hexdigest()))
        os.chmod(c, 0o600)
        self.kw = dict(keys_dir=str(d / "keys.d"), partuuid_dir=str(d / "parts"), udevadm=str(u),
                       require_block=False, require_root=False)

    def tearDown(self):
        self.tmp.cleanup()

    def test_present(self):
        self.assertEqual(status.present_serial(helper, **self.kw), "SWK-ABC")

    def test_absent_when_unplugged_or_wrong_secret(self):
        (self.d / "dev").write_bytes(("SWK1:%s\n" % ("cd" * 32)).encode() + b"\0" * 50)
        self.assertIsNone(status.present_serial(helper, **self.kw))
        os.unlink(self.d / "parts" / PARTUUID)
        self.assertIsNone(status.present_serial(helper, **self.kw))

    def test_no_keys_dir(self):
        self.kw["keys_dir"] = str(self.d / "nope")
        self.assertIsNone(status.present_serial(helper, **self.kw))

    def test_write_status_is_atomic_json_and_world_readable(self):
        out = str(self.d / "run" / "status")
        status.write_status("SWK-ABC", out)
        self.assertEqual(json.load(open(out)), {"present": True, "serial": "SWK-ABC"})
        self.assertEqual(os.stat(out).st_mode & 0o777, 0o644)
        status.write_status(None, out)
        self.assertEqual(json.load(open(out)), {"present": False})
        self.assertFalse(os.path.exists(out + ".tmp"))

    def test_status_file_never_contains_the_secret(self):
        out = str(self.d / "status")
        status.write_status(status.present_serial(helper, **self.kw), out)
        self.assertNotIn(SECRET, open(out).read())


if __name__ == "__main__":
    unittest.main()
