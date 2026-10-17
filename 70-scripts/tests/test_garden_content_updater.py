#!/usr/bin/env python3
"""Fixture test for airootfs/usr/lib/swarm/garden-content-updater.sh.

The real script runs as root under systemd on the installed system. Here we
exercise it under a temp workspace with GARDEN_PHOTOS_SOURCE and _DEST env
overrides so we can prove the copy rules and edge cases without touching
/opt/swarm_os/garden or a real mount.
"""

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[2] / (
    '40-iso-profile/swarm_os_iso_profile/airootfs/usr/lib/swarm/garden-content-updater.sh'
)


class GardenContentUpdaterTest(unittest.TestCase):
    def setUp(self):
        self.assertTrue(SCRIPT.exists(), f'script missing at {SCRIPT}')
        self.assertTrue(os.access(SCRIPT, os.X_OK), 'script must be executable')
        self.workspace = tempfile.mkdtemp(prefix='garden-updater-')
        self.src = os.path.join(self.workspace, 'src')
        self.dst = os.path.join(self.workspace, 'dst')

    def tearDown(self):
        shutil.rmtree(self.workspace, ignore_errors=True)

    def run_script(self, env_extra=None):
        env = os.environ.copy()
        env['GARDEN_PHOTOS_SOURCE'] = self.src
        env['GARDEN_PHOTOS_DEST']   = self.dst
        if env_extra:
            env.update(env_extra)
        return subprocess.run(
            [str(SCRIPT)],
            env=env, capture_output=True, text=True, check=False,
        )

    def touch(self, path, content=b'x'):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'wb') as f:
            f.write(content)

    # ── Behaviour tests ──────────────────────────────────────────────────

    def test_source_missing_is_success(self):
        # No src directory — the reference mount is offline. Script exits 0.
        r = self.run_script()
        self.assertEqual(r.returncode, 0, msg=r.stderr)
        self.assertIn('source', r.stderr)
        self.assertIn('offline', r.stderr)

    def test_copies_supported_image_types(self):
        os.makedirs(self.src)
        for name in ('lucille_og.jpg', 'purple_punch.png', 'blue_dream.webp',
                     'wedding_cake.JPEG'):
            self.touch(os.path.join(self.src, name), b'imgdata')
        r = self.run_script()
        self.assertEqual(r.returncode, 0, msg=r.stderr)
        for name in ('lucille_og.jpg', 'purple_punch.png', 'blue_dream.webp',
                     'wedding_cake.JPEG'):
            self.assertTrue(os.path.exists(os.path.join(self.dst, name)),
                            f'{name} not copied')

    def test_skips_non_image_files(self):
        os.makedirs(self.src)
        self.touch(os.path.join(self.src, 'lucille_og.jpg'), b'imgdata')
        self.touch(os.path.join(self.src, 'notes.txt'), b'do not sync me')
        self.touch(os.path.join(self.src, 'thumbs.db'), b'garbage')
        self.touch(os.path.join(self.src, 'malicious.sh'), b'#!/bin/sh\necho pwned')
        r = self.run_script()
        self.assertEqual(r.returncode, 0, msg=r.stderr)
        self.assertTrue(os.path.exists(os.path.join(self.dst, 'lucille_og.jpg')))
        for bad in ('notes.txt', 'thumbs.db', 'malicious.sh'):
            self.assertFalse(os.path.exists(os.path.join(self.dst, bad)),
                             f'{bad} should not have been copied')

    def test_update_flag_keeps_newer_local_copy(self):
        # Simulate a user having a newer version at DEST that shouldn't be
        # clobbered by a stale SOURCE.
        os.makedirs(self.src)
        os.makedirs(self.dst)
        src_file = os.path.join(self.src, 'blue_dream.jpg')
        dst_file = os.path.join(self.dst, 'blue_dream.jpg')
        self.touch(src_file, b'old')
        self.touch(dst_file, b'newer')
        # Force DEST mtime to be newer than SOURCE.
        os.utime(src_file, (1_600_000_000, 1_600_000_000))
        os.utime(dst_file, (1_700_000_000, 1_700_000_000))

        r = self.run_script()
        self.assertEqual(r.returncode, 0, msg=r.stderr)
        # DEST must still contain "newer".
        with open(dst_file, 'rb') as f:
            self.assertEqual(f.read(), b'newer')

    def test_refuses_root_paths(self):
        r = self.run_script(env_extra={'GARDEN_PHOTOS_SOURCE': '/'})
        self.assertNotEqual(r.returncode, 0)

    def test_creates_dest_when_missing(self):
        os.makedirs(self.src)
        self.touch(os.path.join(self.src, 'runtz.jpg'), b'x')
        # Deliberately do NOT create dst.
        r = self.run_script()
        self.assertEqual(r.returncode, 0, msg=r.stderr)
        self.assertTrue(os.path.exists(os.path.join(self.dst, 'runtz.jpg')))

    def test_new_file_added_between_runs(self):
        os.makedirs(self.src)
        self.touch(os.path.join(self.src, 'og_kush.jpg'), b'v1')
        r1 = self.run_script()
        self.assertEqual(r1.returncode, 0)
        self.assertTrue(os.path.exists(os.path.join(self.dst, 'og_kush.jpg')))

        # Add another strain and re-run.
        self.touch(os.path.join(self.src, 'gelato.png'), b'v1')
        r2 = self.run_script()
        self.assertEqual(r2.returncode, 0)
        self.assertTrue(os.path.exists(os.path.join(self.dst, 'gelato.png')))

    def test_service_unit_wired(self):
        """Timer + service files exist and reference the shipped script."""
        base = Path(__file__).resolve().parents[2] / '40-iso-profile/swarm_os_iso_profile/airootfs'
        service = base / 'etc/systemd/system/swarm-garden-updater.service'
        timer   = base / 'etc/systemd/system/swarm-garden-updater.timer'
        wants   = base / 'etc/systemd/system/timers.target.wants/swarm-garden-updater.timer'
        self.assertTrue(service.exists())
        self.assertTrue(timer.exists())
        self.assertTrue(wants.is_symlink(), 'timer not enabled via wants symlink')
        service_text = service.read_text()
        self.assertIn('/usr/lib/swarm/garden-content-updater.sh', service_text)
        self.assertIn('local-fs.target', service_text)
        # Directives (not commentary) that would tie us to network readiness.
        for directive in ('After=network', 'Requires=network', 'Wants=network',
                          'After=network-online.target'):
            self.assertNotIn(directive, service_text,
                             f'service must not use {directive} — offline-only sync')


if __name__ == '__main__':
    unittest.main()
