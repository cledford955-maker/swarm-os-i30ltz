"""Guard the tty ownership and Archiso file modes behind the kiosk regressions."""
import configparser
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
PROFILE = ROOT / '40-iso-profile/swarm_os_iso_profile'


class DesktopBootContract(unittest.TestCase):
    def test_recovery_console_does_not_steal_desktop_tty(self):
        seat = configparser.ConfigParser()
        seat.read(PROFILE / 'airootfs/etc/systemd/logind.conf.d/99-swarm-seat.conf')
        service = (PROFILE / 'airootfs/etc/systemd/system/swarm-ui.service').read_text()
        tty = next(line.split('=', 1)[1] for line in service.splitlines()
                   if line.startswith('TTYPath='))
        self.assertNotEqual(tty, '/dev/tty' + seat['Login']['ReserveVT'])
        self.assertGreater(int(seat['Login']['ReserveVT']), 0)

    def test_getty_handoff_is_ordered(self):
        service = (PROFILE / 'airootfs/etc/systemd/system/swarm-ui.service').read_text()
        directives = {}
        for line in service.splitlines():
            if line and not line.startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                directives.setdefault(key, []).extend(value.split())
        self.assertIn('getty@tty1.service', directives['Conflicts'])
        self.assertIn('getty@tty1.service', directives['After'])
        self.assertIn('plymouth-quit-wait.service', directives['After'])
        self.assertEqual(directives['Restart'], ['on-failure'])

    def test_archiso_copy_then_permissions_keeps_desktop_programs_executable(self):
        # mkarchiso copies with --no-preserve=ownership,mode before applying
        # file_permissions. A source chmod alone is therefore insufficient.
        programs = ('/opt/swarm_os/swarm_flutter/swarm_flutter',
                    '/opt/swarm_os/swarm-slint/swarm-slint',
                    '/opt/swarm_os/swarm-overlay/swarm-overlay',
                    '/opt/swarm_os/GoogleWorkspaceService/GoogleWorkspaceService',
                    '/usr/local/bin/swarm-overlay-toggle.sh',
                    '/usr/local/bin/swarm-diagnostics',
                    '/usr/local/bin/lucille_wake_listener.py')
        script = '''
declare -A file_permissions=()
source "$1"
shift
for path in "$@"; do printf '%s\n' "${file_permissions[$path]-missing}"; done
'''
        values = subprocess.check_output(
            ['bash', '-c', script, 'profile-check', str(PROFILE / 'profiledef.sh'),
             *programs], text=True).splitlines()
        with tempfile.TemporaryDirectory() as temp:
            source = Path(temp) / 'source'
            source.write_text('#!/bin/sh\nexit 0\n')
            source.chmod(0o755)
            for index, (program, value) in enumerate(zip(programs, values)):
                with self.subTest(program=program):
                    self.assertNotEqual(value, 'missing')
                    mode = int(value.split(':')[2], 8)
                    dest = Path(temp) / str(index)
                    subprocess.run(['cp', '-a', '--no-preserve=ownership,mode',
                                    str(source), str(dest)], check=True)
                    dest.chmod(mode)
                    self.assertEqual(mode & 0o111, 0o111)
                    self.assertEqual(mode & 0o022, 0)
                    subprocess.run([str(dest)], check=True)


if __name__ == '__main__':
    unittest.main()
