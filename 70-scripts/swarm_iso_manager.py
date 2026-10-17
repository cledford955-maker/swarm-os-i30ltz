#!/usr/bin/env python3
"""Maintain the single current SWARM OS ISO stored in the project."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import time

PROJECT = Path('/mnt/Lucy')
STORE = PROJECT / '10-releases'
ISO_RE = re.compile(r'^swarm[-_]os[-_]v?\d.*\.iso$', re.I)
KEEP = 1


def releases(store):
    return sorted((p for p in store.glob('*.iso') if p.is_file() and not p.is_symlink()
                   and ISO_RE.fullmatch(p.name)),
                  key=lambda p: (p.stat().st_mtime_ns, p.name), reverse=True)


def status(path):
    side = path.with_name(path.name + '.json')
    return json.loads(side.read_text()).get('boot_gate', 'untested') if side.is_file() else 'untested'


def atomic_text(path, value):
    tmp = path.with_name(path.name + '.tmp')
    with tmp.open('w') as f:
        f.write(value)
        f.flush()
        os.fsync(f.fileno())
    tmp.replace(path)


def latest(store):
    pointer = store / 'latest.txt'
    if pointer.is_file():
        name = pointer.read_text().strip()
        if Path(name).name == name and ISO_RE.fullmatch(name):
            candidate = store / name
            if candidate.is_file() and not candidate.is_symlink() and status(candidate) != 'failed':
                return candidate
    for candidate in releases(store):
        if status(candidate) != 'failed':
            return candidate
    candidates = releases(store)
    if candidates:
        return candidates[0]
    raise RuntimeError(f'No SWARM ISO exists in {store}.')


def update_latest(store):
    try:
        candidate = latest(store)
    except RuntimeError:
        (store / 'latest.txt').unlink(missing_ok=True)
    else:
        atomic_text(store / 'latest.txt', candidate.name + '\n')


def prune(store, dry_run=False):
    images = releases(store)
    preferred = None
    try:
        preferred = latest(store)
    except RuntimeError:
        pass
    kept = preferred or (images[0] if images else None)
    removed = [p for p in images if p != kept]
    for path in removed:
        print(('Would remove ' if dry_run else 'Removing ') + path.name)
        if not dry_run:
            path.unlink()
            for suffix in ('.json', '.sha256', '.sha256.asc', '.stable'):
                path.with_name(path.name + suffix).unlink(missing_ok=True)
    if not dry_run:
        update_latest(store)
    return removed


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(8 * 1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def publish(store, source, name, result):
    if result not in ('pass', 'failed', 'untested'):
        raise ValueError('Invalid boot gate result')
    if not ISO_RE.fullmatch(name) or Path(name).name != name:
        raise ValueError('Invalid versioned ISO name')
    source = source.resolve(strict=True)
    if not source.is_relative_to(store / '.incoming'):
        raise ValueError(f'Build output must be inside {store}/.incoming')
    target = store / name
    if target.exists():
        raise FileExistsError(target)
    checksum = digest(source)
    source.replace(target)
    atomic_text(target.with_name(name + '.sha256'), f'{checksum}  {name}\n')
    atomic_text(target.with_name(name + '.json'), json.dumps(
        {'boot_gate': result, 'published': time.strftime('%Y-%m-%dT%H:%M:%S%z')}, indent=2) + '\n')
    if result != 'failed':
        atomic_text(store / 'latest.txt', name + '\n')
    prune(store)
    print(target)


def stable(image, mark, note=''):
    sidecar = image.with_name(image.name + '.stable')
    if mark:
        atomic_text(sidecar, note.strip() + '\n')
    else:
        sidecar.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    subs = parser.add_subparsers(dest='command', required=True)
    for command in ('check', 'latest', 'list'):
        subs.add_parser(command)
    sub = subs.add_parser('prune')
    sub.add_argument('--dry-run', action='store_true')
    for command in ('stable', 'unmark-stable'):
        sub = subs.add_parser(command)
        sub.add_argument('iso')
        sub.add_argument('--note', default='Marked stable by user')
    sub = subs.add_parser('publish')
    sub.add_argument('source', type=Path)
    sub.add_argument('name')
    sub.add_argument('--result', choices=('pass', 'failed', 'untested'), required=True)
    args = parser.parse_args()
    store = STORE
    if args.command == 'check':
        if store.is_symlink():
            raise RuntimeError(f'Release directory must not be a symlink: {store}')
        store.mkdir(parents=True, exist_ok=True)
        print(store)
        return
    if not store.is_dir() or store.is_symlink():
        raise RuntimeError(f'Missing or unsafe project release directory: {store}')
    if args.command == 'latest':
        print(latest(store))
        return
    if args.command == 'list':
        for path in releases(store):
            print(('STABLE' if path.with_name(path.name + '.stable').exists() else 'rolling') + '\t' + status(path) + '\t' + path.name)
        return
    lock = PROJECT / '70-scripts/.iso-manager.lock'
    with lock.open('a') as f:
        fcntl.flock(f, fcntl.LOCK_EX)
        if args.command == 'prune':
            prune(store, args.dry_run)
        elif args.command in ('stable', 'unmark-stable'):
            image = Path(args.iso).resolve(strict=True)
            if image.parent != store or not ISO_RE.fullmatch(image.name):
                raise ValueError('Choose the current versioned ISO in 10-releases')
            stable(image, args.command == 'stable', args.note)
        elif args.command == 'publish':
            publish(store, args.source, args.name, args.result)


if __name__ == '__main__':
    try:
        main()
    except (OSError, RuntimeError, ValueError, FileExistsError) as exc:
        sys.exit('ISO manager: ' + str(exc))
