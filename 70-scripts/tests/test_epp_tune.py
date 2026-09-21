import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
PROFILE = ROOT / '40-iso-profile/swarm_os_iso_profile'
SCRIPT = PROFILE / 'airootfs/usr/lib/swarm/epp-tune.sh'


class EppTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.sysfs = self.root / 'sys'
        self.sysfs.mkdir()
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        fake = self.bin / 'systemctl'
        fake.write_text('#!/bin/sh\n[ "$3" = "$TEST_MANAGER" ]\n')
        fake.chmod(0o755)
        self.env = {**os.environ, 'PATH': f'{self.bin}:' + os.environ['PATH'], 'TEST_MANAGER': '',
                    'SWARM_EPP_AC': 'balance_performance', 'SWARM_EPP_BATTERY': 'balance_power'}

    def write(self, path, value):
        path = self.sysfs / path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(value + '\n')
        return path

    def policy(self, number=0, choices='performance balance_performance balance_power power', governor='powersave'):
        base = f'devices/system/cpu/cpufreq/policy{number}'
        self.write(base + '/energy_performance_available_preferences', choices)
        self.write(base + '/scaling_governor', governor)
        return self.write(base + '/energy_performance_preference', 'performance')

    def battery(self):
        self.write('class/power_supply/BAT0/type', 'Battery')
        self.write('class/power_supply/BAT0/present', '1')

    def run_script(self, *args):
        return subprocess.run([str(SCRIPT), '--sysfs', str(self.sysfs), *args],
                              env=self.env, capture_output=True, text=True, timeout=5)

    def test_desktop_ac_all_policies_idempotent(self):
        files = [self.policy(0), self.policy(4)]
        self.assertEqual(self.run_script().returncode, 0)
        for file in files:
            self.assertEqual(file.read_text().strip(), 'balance_performance')
        self.assertEqual(self.run_script().stdout, '')

    def test_ac_battery_transition(self):
        pref = self.policy()
        self.battery()
        self.assertEqual(self.run_script().returncode, 0)
        self.assertEqual(pref.read_text().strip(), 'balance_power')
        self.write('class/power_supply/AC/type', 'Mains')
        online = self.write('class/power_supply/AC/online', '1')
        self.run_script()
        self.assertEqual(pref.read_text().strip(), 'balance_performance')
        online.write_text('0\n')
        self.run_script()
        self.assertEqual(pref.read_text().strip(), 'balance_power')

    def test_peripheral_battery_ignored(self):
        pref = self.policy()
        self.battery()
        self.write('class/power_supply/BAT0/scope', 'Device')
        self.run_script()
        self.assertEqual(pref.read_text().strip(), 'balance_performance')

    def test_status_never_writes(self):
        pref = self.policy()
        result = self.run_script('--status')
        self.assertIn('read-only', result.stdout)
        self.assertEqual(pref.read_text().strip(), 'performance')

    def test_other_manager_yields(self):
        pref = self.policy()
        for manager in ['power-profiles-daemon.service', 'tlp.service', 'tuned.service', 'auto-cpufreq.service', 'cpupower.service']:
            self.env['TEST_MANAGER'] = manager
            self.assertIn('delegated', self.run_script().stdout)
            self.assertEqual(pref.read_text().strip(), 'performance')

    def test_unsupported_cpu_and_preference(self):
        self.assertIn('unsupported', self.run_script().stdout)
        pref = self.policy(choices='performance power')
        self.assertIn('does not support', self.run_script().stdout)
        self.assertEqual(pref.read_text().strip(), 'performance')

    def test_performance_governor_respected(self):
        pref = self.policy(governor='performance')
        self.assertIn('performance governor', self.run_script().stdout)
        self.assertEqual(pref.read_text().strip(), 'performance')

    def test_invalid_config_rejected(self):
        pref = self.policy()
        self.env['SWARM_EPP_AC'] = 'arbitrary'
        self.assertEqual(self.run_script().returncode, 2)
        self.assertEqual(pref.read_text().strip(), 'performance')

    def test_timer_and_executable_staged(self):
        link = PROFILE / 'airootfs/etc/systemd/system/timers.target.wants/swarm-epp.timer'
        self.assertTrue(link.is_symlink())
        self.assertTrue(link.resolve().is_file())
        self.assertTrue(os.access(SCRIPT, os.X_OK))
        self.assertIn('ExecStart=/usr/lib/swarm/epp-tune.sh', (link.parent.parent / 'swarm-epp.service').read_text())


if __name__ == '__main__':
    unittest.main()
