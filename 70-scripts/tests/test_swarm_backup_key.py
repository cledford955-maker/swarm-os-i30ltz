"""Tests for the BACKUP key tier of swarm-key-sudo-auth (arm + slick secret + bound drive + phone approval).

Run: cd 70-scripts/tests && python3 -m unittest test_swarm_backup_key
Uses temp dirs, a stub udevadm and a fake lucille-core IPC socket; touches no real disks.
"""
import hashlib, json, os, pathlib, pwd, socket, tempfile, threading, time, unittest
from test_swarm_key_sudo_auth import helper

SECRET = "9f" * 32
DRIVE_SERIAL = "2523E8D92055"


class FakeLucille(threading.Thread):
    """Answers request_approval like lucille-core does; records what it was asked."""
    def __init__(self, path, approve):
        super().__init__(daemon=True)
        self.path, self.approve, self.requests = path, approve, []
        self.srv = socket.socket(socket.AF_UNIX)
        self.srv.bind(path)
        self.srv.listen(4)
        self.srv.settimeout(0.2)
        self.stop = False

    def run(self):
        while not self.stop:
            try:
                c, _ = self.srv.accept()
            except socket.timeout:
                continue
            data = b""
            while not data.endswith(b"\n"):
                data += c.recv(1024)
            self.requests.append(json.loads(data))
            c.sendall(('{"status":"ok","approved":%s}\n' % ("true" if self.approve else "false")).encode())
            c.close()
        self.srv.close()


class BackupKeyTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(dir="/tmp", prefix="bk")
        self.d = pathlib.Path(self.tmp.name)
        self.keys = self.d / "keys.d"; self.keys.mkdir(); os.chmod(self.keys, 0o755)
        self.slick = self.d / "slick-keys"; self.slick.mkdir()
        self.byid = self.d / "by-id"; self.byid.mkdir()
        self.runuser = self.d / "run-user"; self.runuser.mkdir()
        self.me = pwd.getpwuid(os.getuid())
        (self.runuser / str(self.me.pw_uid)).mkdir()
        self.arm_path = self.runuser / str(self.me.pw_uid) / "swarm-backup-arm"
        self.rate = self.d / "last-attempt"
        self.sock = str(self.d / "ipc.sock")
        self.udev_serial = DRIVE_SERIAL
        self.write_udev()
        (self.byid / ("usb-Micron_CT2000X9SSD9_%s-0:0" % DRIVE_SERIAL)).symlink_to(self.d / "disk")
        (self.d / "disk").write_text("")
        (self.slick / "micron.key").write_text(SECRET + "\n"); os.chmod(self.slick / "micron.key", 0o600)
        self.write_conf()
        self.arm()
        self.lucille = FakeLucille(self.sock, True); self.lucille.start()

    def tearDown(self):
        self.lucille.stop = True
        time.sleep(0.3)
        self.tmp.cleanup()

    def write_udev(self):
        u = self.d / "udevadm"
        u.write_text("#!/bin/sh\necho ID_BUS=usb\necho ID_SERIAL_SHORT=%s\n" % self.udev_serial)
        u.chmod(0o755); self.udev = str(u)

    def write_conf(self, sha=None, **over):
        vals = dict(TIER="backup", KEY_NAME="micron", BIND_USB_SERIAL=DRIVE_SERIAL, SECRET_FILE="micron.key",
                    SECRET_SHA256=sha or hashlib.sha256(SECRET.encode()).hexdigest())
        vals.update(over)
        f = self.keys / "BK-micron.conf"
        f.write_text("".join("%s=%s\n" % kv for kv in vals.items())); os.chmod(f, 0o600)

    def arm(self, age=0):
        self.arm_path.write_text("")
        t = time.time() - age
        os.utime(self.arm_path, (t, t))

    def check(self, **kw):
        args = dict(keys_dir=str(self.keys), partuuid_dir=str(self.d), udevadm=self.udev, require_block=False,
                    require_root=False, ruser=self.me.pw_name, run_user_dir=str(self.runuser),
                    slick_dir=str(self.slick), lucille_sock=self.sock, rate_file=str(self.rate),
                    approval_timeout=10, byid_dir=str(self.byid))
        args.update(kw)
        return helper.verify(**args)

    def test_everything_ok_and_phone_approves(self):
        self.assertTrue(self.check())
        self.assertEqual(len(self.lucille.requests), 1)
        self.assertEqual(self.lucille.requests[0]["command"], "request_approval")
        self.assertIn("micron", self.lucille.requests[0]["text"])

    def test_phone_denies(self):
        self.lucille.approve = False
        self.assertFalse(self.check())

    def test_not_armed_never_asks_the_phone(self):
        self.arm_path.unlink()
        self.assertFalse(self.check())
        self.assertEqual(self.lucille.requests, [])

    def test_stale_arm_rejected_and_arm_is_single_use(self):
        self.arm(age=300)
        self.assertFalse(self.check())
        self.assertFalse(self.arm_path.exists())
        self.arm()
        self.assertTrue(self.check())
        self.assertFalse(self.arm_path.exists())
        self.rate.unlink()
        self.assertFalse(self.check())  # arm already used

    def test_arm_symlink_and_wrong_owner_rejected(self):
        self.arm_path.unlink()
        other = self.d / "elsewhere"; other.write_text("")
        self.arm_path.symlink_to(other)
        self.assertFalse(self.check())
        self.assertEqual(self.lucille.requests, [])

    def test_wrong_secret_in_slick(self):
        (self.slick / "micron.key").write_text("00" * 32 + "\n")
        self.assertFalse(self.check())
        self.assertEqual(self.lucille.requests, [])

    def test_slick_locked_means_no_file(self):
        (self.slick / "micron.key").unlink()
        self.assertFalse(self.check())
        self.assertEqual(self.lucille.requests, [])

    def test_secret_file_must_be_private(self):
        os.chmod(self.slick / "micron.key", 0o644)
        self.assertFalse(self.check())

    def test_symlinked_secret_rejected(self):
        real = self.d / "real.key"; real.write_text(SECRET); os.chmod(real, 0o600)
        (self.slick / "micron.key").unlink()
        (self.slick / "micron.key").symlink_to(real)
        self.assertFalse(self.check())

    def test_secret_file_name_cannot_escape(self):
        self.write_conf(SECRET_FILE="../real.key")
        self.assertFalse(self.check())
        self.write_conf(SECRET_FILE="/etc/passwd")
        self.arm(); self.assertFalse(self.check())

    def test_bound_drive_must_be_attached(self):
        self.udev_serial = "SOMEOTHER"; self.write_udev()
        self.assertFalse(self.check())
        self.assertEqual(self.lucille.requests, [])
        self.udev_serial = DRIVE_SERIAL; self.write_udev()
        for f in self.byid.iterdir():
            f.unlink()
        self.arm(); self.assertFalse(self.check())

    def test_no_lucille_means_denied(self):
        self.lucille.stop = True; time.sleep(0.4)
        os.unlink(self.sock)
        self.assertFalse(self.check())

    def test_rate_limit(self):
        self.assertTrue(self.check())
        self.arm()
        self.assertFalse(self.check())  # second attempt inside the limit window
        self.assertEqual(len(self.lucille.requests), 1)

    def test_conf_must_be_private(self):
        os.chmod(self.keys / "BK-micron.conf", 0o644)
        self.assertFalse(self.check())

    def test_tampered_registry_hash(self):
        self.write_conf(sha="0" * 64)
        self.assertFalse(self.check())

    def test_stick_path_still_wins_without_arming(self):
        # a genuine stick key is checked first and never needs the backup path
        pu = "3f2b8c1e-5d4a-4e7b-9a60-1c2d3e4f5a6b"
        dev = self.d / "stick"; dev.write_bytes(("SWK1:%s\n" % ("ab" * 32)).encode() + b"\0" * 50)
        (self.d / pu).symlink_to(dev)
        stub = self.d / "udevadm"
        stub.write_text("#!/bin/sh\necho ID_BUS=usb\necho ID_SERIAL_SHORT=%s\necho ID_PART_ENTRY_UUID=%s\n" % (DRIVE_SERIAL, pu))
        stub.chmod(0o755)
        f = self.keys / "SWK-STICK.conf"
        f.write_text("PARTUUID=%s\nHWSERIAL=%s\nSECRET_SHA256=%s\n" % (pu, DRIVE_SERIAL, hashlib.sha256(("ab" * 32).encode()).hexdigest()))
        os.chmod(f, 0o600)
        self.arm_path.unlink()
        self.assertTrue(self.check())
        self.assertEqual(self.lucille.requests, [])


if __name__ == "__main__":
    unittest.main()
