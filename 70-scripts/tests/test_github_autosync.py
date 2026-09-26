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
            # Fake git that logs all calls and handles the snapshot-sync commands.
            # sync_subtree() calls: rev-parse, cat-file, fetch, rev-parse, rev-parse,
            # commit-tree, push.  The origin push uses plain "push origin main".
            git.write_text('''#!/bin/bash
printf '%s\\n' "$*" >> "$SYNC_TEST_LOG"
case "$1" in
 rev-parse)
   # --verify --quiet HEAD:<prefix>  →  fake tree hash
   if [[ "$*" == *"HEAD:"* ]]; then echo "abcd1234tree"; exit 0; fi
   # FETCH_HEAD  →  fake remote tip
   if [[ "$*" == *"FETCH_HEAD"* ]]; then echo "remote0001tip"; exit 0; fi
   # <tip>^{tree}  →  different hash so sync is never "up to date"
   if [[ "$*" == *"^{tree}"* ]]; then echo "different_tree"; exit 0; fi
   echo "$SWARM_SYNC_REPO_DIR/sync.lock"
   ;;
 cat-file) echo "tree" ;;
 status) [[ ${DIRTY:-0} == 0 ]] || echo ' M example'; exit 0 ;;
 add) exit "${FAIL_ADD:-0}" ;;
 fetch)
   # fetch --quiet <remote> main
   [[ "$*" != *'i30ltz-recovery'* ]] || exit "${FAIL_RECOVERY:-0}"
   exit 0
   ;;
 commit-tree) echo "newcommit0001" ;;
 push)
   # push origin main  OR  push --quiet <remote> <sha>:refs/heads/main
   [[ "$*" != *'origin main'* ]] || exit "${FAIL_ORIGIN:-0}"
   [[ "$*" != *'i30ltz-recovery'* ]] || exit "${FAIL_RECOVERY:-0}"
   exit 0
   ;;
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
        """Verify that origin push and all 3 snapshot syncs were attempted."""
        self.assertTrue(any('push origin main' in c for c in calls), 'origin push missing')
        for remote in ('i30ltz-recovery', 'i30ltz-swarm-companion', 'i30ltz-lucille-assistant'):
            self.assertTrue(
                any(('fetch' in c or 'push' in c) and remote in c for c in calls),
                f'{remote} sync not attempted')

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
