#!/usr/bin/env python3
"""Three-way sync of a committed subdirectory and a standalone repo's main.

Called under auto_sync_github.sh's lock. State refs remember the last common
snapshot. No force push, subtree history splicing, or conflict resolution.
"""
import argparse
import os
from pathlib import Path
import subprocess
import sys


def git(*args, data=None, check=True):
    p = subprocess.run(['git', *args], input=data, stdout=subprocess.PIPE,
                       stderr=subprocess.PIPE, env={**os.environ, 'GIT_TERMINAL_PROMPT': '0'},
                       timeout=90)
    if check and p.returncode:
        raise RuntimeError('git ' + args[0] + ' failed (see repository/service status)')
    return p


def value(*args):
    return git(*args).stdout.decode().strip()


def sync(prefix, remote):
    if prefix.startswith('/') or '..' in Path(prefix).parts:
        raise RuntimeError('invalid project prefix')
    ref = 'refs/swarm-sync/' + remote + '/base'
    git('check-ref-format', ref)
    if value('branch', '--show-current') != 'main':
        raise RuntimeError('local checkout is not main')
    for name in ('MERGE_HEAD', 'CHERRY_PICK_HEAD', 'REVERT_HEAD', 'rebase-merge', 'rebase-apply', 'index.lock'):
        if Path(value('rev-parse', '--git-path', name)).exists():
            raise RuntimeError('Git operation in progress')
    if git('diff', '--cached', '--quiet', check=False).returncode:
        raise RuntimeError('staged changes need to be committed first')
    if value('status', '--porcelain', '--', prefix):
        raise RuntimeError('project has unsaved local edits; retry after checkpoint')
    head = value('rev-parse', 'HEAD')
    local = value('rev-parse', 'HEAD:' + prefix)
    if value('cat-file', '-t', local) != 'tree':
        raise RuntimeError('project prefix is not a directory')
    # Fetch task branches too, retaining their work without merging unfinished tasks.
    git('fetch', '--quiet', remote, '+refs/heads/*:refs/remotes/' + remote + '/*')
    tip = value('rev-parse', remote + '/main')
    remote_tree = value('rev-parse', tip + '^{tree}')
    if local == remote_tree:
        git('update-ref', ref, tip)
        print('SYNC OK: ' + remote + ' (up to date)')
        return
    base_result = git('rev-parse', '--verify', '--quiet', ref, check=False)
    if base_result.returncode:
        raise RuntimeError('no verified common snapshot; refusing to overwrite either side')
    base = base_result.stdout.decode().strip()
    if git('merge-base', '--is-ancestor', base, tip, check=False).returncode:
        raise RuntimeError('remote history changed; manual review required')
    local_commit = value('commit-tree', local, '-p', base, '-m', 'sync: local project snapshot')
    merged = git('merge-tree', '--write-tree', local_commit, tip, check=False)
    if merged.returncode:
        raise RuntimeError('conflicting edits; both sides preserved, resolve manually')
    tree = merged.stdout.decode().splitlines()[0]
    if tree != local:
        patch = git('diff', '--binary', '--no-ext-diff', '--no-textconv', local, tree).stdout
        if value('rev-parse', 'HEAD') != head or value('status', '--porcelain', '--', prefix):
            raise RuntimeError('local project changed during sync; retry later')
        if git('diff', '--cached', '--quiet', check=False).returncode:
            raise RuntimeError('index changed during sync; retry later')
        git('apply', '--check', '--index', '--directory=' + prefix, data=patch)
        git('apply', '--index', '--directory=' + prefix, data=patch)
        git('commit', '-m', 'sync: import ' + remote + ' main')
    published = tip
    if tree != remote_tree:
        # Only the destination repo's history is a parent of the exported commit.
        published = value('commit-tree', tree, '-p', tip, '-m', 'auto-sync: reconcile local and GitHub changes')
        git('push', '--quiet', remote, published + ':refs/heads/main')
    git('update-ref', ref, published, base)
    print('SYNC OK: ' + remote + ' (two-way)')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('prefix')
    parser.add_argument('remote')
    args = parser.parse_args()
    try:
        sync(args.prefix, args.remote)
    except (RuntimeError, subprocess.TimeoutExpired) as exc:
        print('SYNC FAILED: ' + args.remote + ': ' + str(exc), file=sys.stderr)
        sys.exit(1)
