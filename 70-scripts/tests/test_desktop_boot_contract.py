"""Guard the tty ownership and Archiso file modes behind the kiosk regressions."""
import configparser
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
PROFILE = ROOT / '40-iso-profile/swarm_os_iso_profile'
SERVICE = PROFILE / 'airootfs/etc/systemd/system/swarm-ui.service'
CLEANUP = PROFILE / 'airootfs/usr/lib/swarm/swarm-ui-cleanup.sh'
SESSION = PROFILE / 'airootfs/usr/bin/swarm-session'

# Stub loginctl backed by files: <state>/sessions/<id> holds "Name TTY VTNr"
# (TTY "-" means empty).
# A session whose file also contains "stubborn" ignores terminate-session.
LOGINCTL_STUB = r'''#!/usr/bin/env bash
state="$(dirname "$0")"
echo "$*" >> "$state/calls"
case "$1" in
  list-sessions) for f in "$state"/sessions/*; do [ -e "$f" ] && echo "$(basename "$f") 1000 x"; done ;;
  show-session) read -r name tty vt _ < "$state/sessions/$2"; [ "$tty" = - ] && tty=
                printf 'Name=%s\nTTY=%s\nVTNr=%s\n' "$name" "$tty" "$vt" ;;
  terminate-session) grep -q stubborn "$state/sessions/$2" || rm -f "$state/sessions/$2" ;;
  kill-session) rm -f "$state/sessions/${@: -1}" ;;
esac
'''


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
                    '/usr/local/bin/lucille_wake_listener.py',
                    '/usr/bin/swarm-session',
                    '/usr/lib/swarm/swarm-ui-cleanup.sh')
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



def directive_values(key):
    return [line.split('=', 1)[1] for line in SERVICE.read_text().splitlines()
            if line.startswith(key + '=')]


class DesktopTeardownContract(unittest.TestCase):
    """pam_systemd puts the desktop in a logind scope outside the unit cgroup."""

    def run_cleanup(self, sessions, unit_user='swarm'):
        with tempfile.TemporaryDirectory() as temp:
            state = Path(temp)
            (state / 'sessions').mkdir()
            for session_id, fields in sessions.items():
                (state / 'sessions' / session_id).write_text(fields + '\n')
            loginctl = state / 'loginctl'
            loginctl.write_text(LOGINCTL_STUB)
            systemctl = state / 'systemctl'
            systemctl.write_text(f'#!/bin/sh\necho {unit_user}\n')
            pkill = state / 'pkill'
            pkill.write_text('#!/bin/sh\necho "$*" >> "$(dirname "$0")/pkill_calls"\nexit 1\n')
            for stub in (loginctl, systemctl, pkill):
                stub.chmod(0o755)
            env = dict(os.environ, SWARM_LOGINCTL=str(loginctl),
                       SWARM_SYSTEMCTL=str(systemctl), SWARM_PKILL=str(pkill),
                       SWARM_CLEANUP_GRACE='1')
            subprocess.run([str(CLEANUP)], env=env, check=True, timeout=20,
                           capture_output=True)
            calls = (state / 'calls').read_text().splitlines()
            pkills = (state / 'pkill_calls').read_text().splitlines()
            left = sorted(f.name for f in (state / 'sessions').iterdir())
            return calls, pkills, left

    def test_terminates_only_the_desktop_users_tty1_session(self):
        calls, _, left = self.run_cleanup({
            '3': 'swarm tty1 1',      # the kiosk
            '4': 'swarm tty2 2',      # same user, another console
            '5': 'root tty1 1',       # another user
            '6': 'swarm - 1',          # closing session: TTY cleared, VT kept
        })
        terminated = [c.split()[1] for c in calls if c.startswith('terminate-session')]
        self.assertEqual(sorted(terminated), ['3', '6'])
        self.assertEqual(left, ['4', '5'])
        self.assertFalse(any(c.startswith('kill-session') for c in calls))

    def test_follows_installer_user_rewrite(self):
        # install_swarm_os.sh rewrites User=swarm to User=i30ltz.
        calls, pkills, left = self.run_cleanup(
            {'7': 'i30ltz tty1 1', '8': 'swarm tty1 1'}, unit_user='i30ltz')
        self.assertIn('terminate-session 7', calls)
        self.assertEqual(left, ['8'])
        self.assertTrue(pkills)
        self.assertTrue(all('-u i30ltz' in call for call in pkills))

    def test_escalates_when_session_survives_terminate(self):
        calls, _, left = self.run_cleanup({'9': 'swarm tty1 1 stubborn'})
        self.assertIn('kill-session --signal=SIGKILL 9', calls)
        self.assertEqual(left, [])

    def test_fallback_covers_every_autostarted_program(self):
        _, pkills, _ = self.run_cleanup({})
        autostart = (PROFILE / 'airootfs/home/swarm/.config/labwc/autostart').read_text()
        for program in ('labwc', 'swarm_flutter', 'swarm-slint'):
            with self.subTest(program=program):
                self.assertTrue(any(call.endswith('-x ' + program) for call in pkills))
        self.assertIn('swarm_flutter', autostart)
        self.assertIn('swarm-slint', autostart)

    def test_unit_runs_cleanup_before_start_and_before_tty_reset(self):
        helper = '+/usr/lib/swarm/swarm-ui-cleanup.sh'
        self.assertEqual(directive_values('ExecStartPre')[0], helper)
        stop_post = directive_values('ExecStopPost')
        self.assertEqual(stop_post[0], helper)
        reset = next(i for i, cmd in enumerate(stop_post) if '/usr/bin/reset' in cmd)
        self.assertGreater(reset, stop_post.index(helper))
        # A hardcoded user misses the installed system's i30ltz desktop.
        self.assertNotIn('pkill -u swarm', SERVICE.read_text())


class DesktopLauncherContract(unittest.TestCase):
    def launch(self, **extra_env):
        with tempfile.TemporaryDirectory() as temp:
            stubs = {}
            for name in ('labwc', 'gamescope'):
                stub = Path(temp) / name
                stub.write_text(f'#!/bin/sh\necho {name} "$@"\n')
                stub.chmod(0o755)
                stubs[name] = str(stub)
            env = {k: v for k, v in os.environ.items() if not k.startswith('SWARM_')}
            env.update(SWARM_LABWC_BIN=stubs['labwc'],
                       SWARM_GAMESCOPE_BIN=stubs['gamescope'], **extra_env)
            out = subprocess.run([str(SESSION)], env=env, check=True,
                                 capture_output=True, text=True).stdout
            return out.replace(stubs['labwc'], 'LABWC').split()

    def test_installed_gamescope_does_not_change_default_session(self):
        self.assertEqual(self.launch(), ['labwc'])

    def test_gamescope_mode_is_explicit_and_wraps_labwc(self):
        argv = self.launch(SWARM_GAMESCOPE='1', SWARM_FSR_SHARPNESS='5')
        self.assertEqual(argv[0], 'gamescope')
        self.assertEqual(argv[-2:], ['--', 'LABWC'])
        self.assertIn('--expose-wayland', argv)
        self.assertIn('fsr', argv)

    @unittest.skipUnless(shutil.which('gamescope'), 'gamescope not installed')
    def test_gamescope_flags_exist(self):
        # The first wrapper passed --width/--nested; gamescope exited 1 and
        # the kiosk fell back to the text console.
        help_text = subprocess.run(['gamescope', '--help'], capture_output=True,
                                   text=True).stdout + subprocess.run(
            ['gamescope', '--help'], capture_output=True, text=True).stderr
        known = {word.rstrip(',') for word in help_text.split() if word.startswith('--')}
        argv = self.launch(SWARM_GAMESCOPE='1', SWARM_FSR_SHARPNESS='5')
        for flag in (arg for arg in argv[1:argv.index('--')] if arg.startswith('--')):
            with self.subTest(flag=flag):
                self.assertIn(flag, known)


if __name__ == '__main__':
    unittest.main()
