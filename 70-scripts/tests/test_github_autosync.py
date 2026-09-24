"""Failure-isolation checks with fake Git; never contacts or changes a repository."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'auto_sync_github.sh'


class AutoSync(unittest.TestCase):
    def exercise(self, **overrides):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            git = root / 'git'
            git.write_text('''#!/bin/bash
printf '%s\n' "$*" >> "$SYNC_TEST_LOG"
case "$1" in
 rev-parse) echo "$SWARM_SYNC_REPO_DIR/sync.lock" ;;
 status) [[ ${DIRTY:-0} == 0 ]] || echo ' M example'; exit 0 ;;
 add) exit "${FAIL_ADD:-0}" ;;
 push) exit "${FAIL_ORIGIN:-0}" ;;
 subtree) [[ "$*" != *'i30ltz-recovery main'* ]] || exit "${FAIL_RECOVERY:-0}" ;;
esac
exit 0
''')
            git.chmod(0o755)
            mountpoint = root / 'mountpoint'
            mountpoint.write_text('#!/bin/sh\nexit 1\n')
            mountpoint.chmod(0o755)
            log = root / 'calls'
            env = dict(os.environ, PATH=temp + os.pathsep + os.environ['PATH'],
                       SWARM_SYNC_REPO_DIR=temp, SYNC_TEST_LOG=str(log), **overrides)
            result = subprocess.run(['bash', str(SCRIPT)], env=env, capture_output=True,
                                    text=True, timeout=10)
            return result.returncode, log.read_text().splitlines()

    def assert_all_destinations(self, calls):
        self.assertIn('push origin main', calls)
        for remote in ('i30ltz-recovery', 'i30ltz-swarm-companion', 'i30ltz-lucille-assistant'):
            self.assertTrue(any(call.startswith('subtree ') and call.endswith(remote + ' main')
                                for call in calls), remote)

    def test_clean_tree_retries_every_push(self):
        status, calls = self.exercise()
        self.assertEqual(status, 0)
        self.assert_all_destinations(calls)

    def test_failed_remotes_do_not_skip_other_projects(self):
        status, calls = self.exercise(FAIL_ORIGIN='1', FAIL_RECOVERY='1')
        self.assertEqual(status, 1)
        self.assert_all_destinations(calls)

    def test_staging_failure_does_not_commit_partial_index(self):
        status, calls = self.exercise(DIRTY='1', FAIL_ADD='1')
        self.assertEqual(status, 1)
        self.assertFalse(any(call.startswith('commit ') for call in calls))
        self.assert_all_destinations(calls)


if __name__ == '__main__':
    unittest.main()
