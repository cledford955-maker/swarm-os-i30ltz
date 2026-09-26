"""Real disposable Git repositories; no network or production repository writes."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'sync_project_repo.py'
HOOK = SCRIPT.parents[1] / 'lucille-companion/.claude/cloud_checkpoint.py'


class SyncTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.local = self.root / 'local'
        self.remote = self.root / 'remote.git'
        self.peer = self.root / 'peer'
        self.local.mkdir()
        self.g(self.root, 'init', '--bare', str(self.remote))
        self.g(self.local, 'init', '-b', 'main')
        self.identity(self.local)
        (self.local / 'app').mkdir()
        (self.local / 'app/a.txt').write_text('base\n')
        (self.local / 'private-monorepo.txt').write_text('not for the app repo\n')
        self.commit(self.local)
        tree = self.g(self.local, 'rev-parse', 'HEAD:app')
        tip = self.g(self.local, 'commit-tree', tree, '-m', 'initial app')
        self.g(self.local, 'remote', 'add', 'project', str(self.remote))
        self.g(self.local, 'push', 'project', tip + ':refs/heads/main')
        self.g(self.remote, 'symbolic-ref', 'HEAD', 'refs/heads/main')
        self.g(self.root, 'clone', str(self.remote), str(self.peer))
        self.identity(self.peer)
        self.run_sync()

    def g(self, cwd, *args):
        p = subprocess.run(['git', *args], cwd=cwd, text=True, capture_output=True, timeout=20)
        self.assertEqual(p.returncode, 0, p.stderr)
        return p.stdout.strip()

    def identity(self, cwd):
        self.g(cwd, 'config', 'user.name', 'Fixture')
        self.g(cwd, 'config', 'user.email', 'fixture@example.invalid')

    def commit(self, cwd):
        self.g(cwd, 'add', '-A')
        self.g(cwd, 'commit', '-m', 'fixture edit')

    def run_sync(self, ok=True):
        p = subprocess.run(['python3', str(SCRIPT), 'app', 'project'], cwd=self.local,
                           text=True, capture_output=True, timeout=30)
        self.assertEqual(p.returncode, 0 if ok else 1, p.stdout + p.stderr)
        return p

    def remote_edit(self, name='remote.txt', text='remote\n'):
        (self.peer / name).write_text(text)
        self.commit(self.peer)
        self.g(self.peer, 'push', 'origin', 'main')

    def test_remote_only_import_and_task_branch_fetch(self):
        self.remote_edit()
        self.g(self.peer, 'push', 'origin', 'HEAD:refs/heads/claude/task')
        self.run_sync()
        self.assertEqual((self.local / 'app/remote.txt').read_text(), 'remote\n')
        self.g(self.local, 'rev-parse', 'refs/remotes/project/claude/task')
        self.assertEqual(self.g(self.local, 'status', '--porcelain'), '')

    def test_local_only_and_no_monorepo_history_leak(self):
        (self.local / 'app/local.txt').write_text('local\n')
        self.commit(self.local)
        self.run_sync()
        objects = self.g(self.remote, 'rev-list', '--objects', '--all')
        self.assertNotIn('private-monorepo', objects)
        self.assertEqual(self.g(self.remote, 'show', 'main:local.txt'), 'local')

    def test_independent_changes_merge_and_repeat_is_noop(self):
        (self.local / 'app/local.txt').write_text('local\n')
        self.commit(self.local)
        self.remote_edit()
        self.run_sync()
        tip = self.g(self.remote, 'rev-parse', 'main')
        self.assertEqual(self.g(self.remote, 'show', 'main:local.txt'), 'local')
        self.assertEqual((self.local / 'app/remote.txt').read_text(), 'remote\n')
        self.run_sync()
        self.assertEqual(tip, self.g(self.remote, 'rev-parse', 'main'))

    def test_conflict_preserves_both_and_clean_index(self):
        (self.local / 'app/a.txt').write_text('local\n')
        self.commit(self.local)
        self.remote_edit('a.txt', 'remote\n')
        local = self.g(self.local, 'rev-parse', 'HEAD')
        remote = self.g(self.remote, 'rev-parse', 'main')
        self.assertIn('conflicting edits', self.run_sync(False).stderr)
        self.assertEqual(local, self.g(self.local, 'rev-parse', 'HEAD'))
        self.assertEqual(remote, self.g(self.remote, 'rev-parse', 'main'))
        self.assertEqual(self.g(self.local, 'status', '--porcelain'), '')

    def test_unknown_baseline_and_dirty_work_are_preserved(self):
        self.remote_edit()
        self.g(self.local, 'update-ref', '-d', 'refs/swarm-sync/project/base')
        self.assertIn('no verified common', self.run_sync(False).stderr)
        (self.local / 'app/a.txt').write_text('unsaved\n')
        self.assertIn('unsaved local edits', self.run_sync(False).stderr)
        self.assertEqual((self.local / 'app/a.txt').read_text(), 'unsaved\n')

    def test_push_failure_can_retry_without_losing_import(self):
        (self.local / 'app/local.txt').write_text('local\n')
        self.commit(self.local)
        self.remote_edit()
        reject = self.remote / 'hooks/pre-receive'
        reject.write_text('#!/bin/sh\nexit 1\n'); reject.chmod(0o755)
        self.run_sync(False)
        self.assertTrue((self.local / 'app/remote.txt').exists())
        reject.unlink()
        self.run_sync()
        self.assertEqual(self.g(self.remote, 'show', 'main:local.txt'), 'local')

    def prepare_hook(self):
        self.g(self.peer, 'switch', '-c', 'claude/test')
        (self.peer / '.claude').mkdir()
        shutil.copyfile(HOOK, self.peer / '.claude/cloud_checkpoint.py')
        self.commit(self.peer)

    def run_hook(self, remote='true'):
        return subprocess.run(['python3', str(self.peer / '.claude/cloud_checkpoint.py')],
            cwd=self.peer, env={**os.environ, 'CLAUDE_CODE_REMOTE': remote,
                               'CLAUDE_PROJECT_DIR': str(self.peer)},
            capture_output=True, text=True, timeout=30)

    def test_cloud_checkpoint_pushes_and_excludes_secret_and_generated_files(self):
        self.prepare_hook()
        (self.peer / 'source.txt').write_text('work\n')
        (self.peer / '.env').write_text('EXAMPLE=private\n')
        (self.peer / 'target').mkdir()
        (self.peer / 'target/binary').write_text('generated\n')
        self.assertEqual(self.run_hook().returncode, 0)
        self.assertEqual(self.g(self.remote, 'show', 'claude/test:source.txt'), 'work')
        files = self.g(self.remote, 'ls-tree', '-r', '--name-only', 'claude/test')
        self.assertNotIn('.env', files)
        self.assertNotIn('target/binary', files)
        self.assertEqual(self.g(self.remote, 'show', 'main:a.txt'), 'base')

    def test_hook_disabled_locally_and_on_main_and_preserves_staging(self):
        self.prepare_hook()
        (self.peer / 'a.txt').write_text('changed\n')
        before = self.g(self.peer, 'rev-parse', 'HEAD')
        self.run_hook('false')
        self.assertEqual(before, self.g(self.peer, 'rev-parse', 'HEAD'))
        self.g(self.peer, 'add', 'a.txt')
        self.assertIn('existing staged', self.run_hook().stderr)
        self.assertEqual(before, self.g(self.peer, 'rev-parse', 'HEAD'))
        self.g(self.peer, 'reset', 'HEAD', 'a.txt')
        self.g(self.peer, 'branch', '-m', 'claude/test', 'plain-task')
        self.assertIn('claude/*', self.run_hook().stderr)
        self.assertEqual(before, self.g(self.peer, 'rev-parse', 'HEAD'))

    def test_cloud_checkpoint_retries_failed_push_without_new_edits(self):
        self.prepare_hook()
        (self.peer / 'source.txt').write_text('work\n')
        reject = self.remote / 'hooks/pre-receive'
        reject.write_text('#!/bin/sh\nexit 1\n'); reject.chmod(0o755)
        self.assertIn('Git push failed', self.run_hook().stderr)
        checkpoint = self.g(self.peer, 'rev-parse', 'HEAD')
        self.assertEqual(self.g(self.peer, 'status', '--porcelain'), '')
        reject.unlink()
        self.assertEqual(self.run_hook().returncode, 0)
        self.assertEqual(self.g(self.remote, 'rev-parse', 'claude/test'), checkpoint)

    def test_hook_rejects_embedded_credential(self):
        self.prepare_hook()
        (self.peer / 'a.txt').write_text('token = "ghp_' + 'x' * 36 + '"\n')
        before = self.g(self.peer, 'rev-parse', 'HEAD')
        self.assertIn('possible credential', self.run_hook().stderr)
        self.assertEqual(before, self.g(self.peer, 'rev-parse', 'HEAD'))
        self.assertEqual(self.g(self.peer, 'diff', '--cached', '--name-only'), '')


if __name__ == '__main__':
    unittest.main()
