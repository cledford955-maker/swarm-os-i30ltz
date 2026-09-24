#!/usr/bin/env python3
"""Apply the reviewed ISO inventory plan, refusing changed files or symlink paths."""
import argparse
import contextlib
import fcntl
import json
import os
from pathlib import Path
import shutil
import sys

import swarm_iso_manager as iso

PLAN = Path('/mnt/Lucy/70-scripts/iso_cleanup_20260924.json')
ROOTS = tuple(map(Path, ('/mnt/Lucy', '/mnt/ventoy', '/home/i30ltz',
                        '/mnt/endeavor', '/mnt/recoverybuild', '/mnt/recoveryos', '/mnt/brains')))


def validate(record):
    path = Path(record['path'])
    if path.suffix.lower() != '.iso' or not any(path.is_relative_to(root) for root in ROOTS):
        raise RuntimeError('Path is outside the reviewed ISO locations: '+str(path))
    if path.is_symlink() or path.resolve() != path:
        raise RuntimeError('Refusing redirected path: '+str(path))
    if not path.exists():
        return None
    stat = path.stat()
    actual = (stat.st_dev, stat.st_ino, stat.st_size, stat.st_mtime_ns)
    expected = tuple(record[k] for k in ('device', 'inode', 'bytes', 'mtime_ns'))
    if actual != expected:
        raise RuntimeError('ISO changed since review; regenerate the plan: '+str(path))
    return path


def apply(plan, owned_only=False):
    iso.require_store()
    # Validate the complete plan before any deletion. Missing deletion targets
    # are allowed on retries; retained images must still exist somewhere.
    for record in plan['delete']:
        validate(record)
    for record in plan['keep']:
        source = validate(record)
        target = Path(record['destination'])
        if target.parent != iso.STORE or target.resolve() != target:
            raise RuntimeError('Retained image must live directly in the SWARM store.')
        if source is None:
            if target.is_symlink() or not target.is_file() or target.stat().st_size != record['bytes']:
                raise RuntimeError('A retained image is missing: '+str(target))
            if record.get('sha256') and iso.digest(target) != record['sha256']:
                raise RuntimeError('Retained image checksum mismatch: '+str(target))
    moved = removed = freed = 0
    if not owned_only:
        for record in plan['keep']:
            source = Path(record['path']); target = Path(record['destination'])
            if source == target or not source.exists():
                continue
            checksum = iso.digest(source)
            if record.get('sha256') and checksum != record['sha256']:
                raise RuntimeError('Retained source checksum mismatch: '+str(source))
            if target.exists():
                if iso.digest(target) != checksum:
                    raise RuntimeError('Different images share a destination: '+str(target))
                source.unlink()
            elif source.stat().st_dev == target.parent.stat().st_dev:
                source.replace(target)
            else:
                temporary = target.with_name(target.name+'.partial')
                with temporary.open('xb') as output, source.open('rb') as input_file:
                    shutil.copyfileobj(input_file, output, length=8*1024*1024)
                    output.flush(); os.fsync(output.fileno())
                if iso.digest(temporary) != checksum:
                    raise RuntimeError('Retained copy checksum mismatch: '+str(source))
                shutil.copystat(source, temporary)
                temporary.replace(target)
                source.unlink()
            iso.atomic_text(target.with_name(target.name+'.sha256'), checksum+'  '+target.name+'\n')
            if not target.with_name(target.name+'.json').exists():
                iso.atomic_text(target.with_name(target.name+'.json'),
                                json.dumps({'boot_gate':'untested', 'imported':'2026-09-24'})+'\n')
            moved += 1
            print('Retained on Ventoy:',target,flush=True)
    for record in plan['delete']:
        path = validate(record)
        if path is None:
            continue
        if owned_only and not os.access(path.parent, os.W_OK):
            continue
        path.unlink()
        for suffix in ('.sha256', '.json', '.stable'):
            path.with_name(path.name+suffix).unlink(missing_ok=True)
        removed += 1; freed += record['bytes']
        print('Removed:',path,flush=True)
    if not owned_only:
        remaining = iso.all_isos(iso.MOUNT)
        expected = {Path(record['destination']) for record in plan['keep']}
        if set(remaining) != expected:
            raise RuntimeError('Ventoy inventory changed: expected exactly the ten reviewed retained images.')
        if any(Path(record['path']).exists() for record in plan['delete']):
            raise RuntimeError('Some surplus files remain.')
        iso.update_latest(iso.STORE)
    print(json.dumps({'moved':moved,'removed':removed,'freed_bytes':freed,'owned_only':owned_only}))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--owned-only', action='store_true')
    args = parser.parse_args()
    plan = json.loads(PLAN.read_text())
    if not args.apply:
        print(json.dumps(plan, indent=2));return
    with contextlib.ExitStack() as stack:
        for name in ('.swarm-build.lock', '.iso-manager.lock'):
            lock = stack.enter_context((iso.PROJECT/'70-scripts'/name).open('a'))
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        apply(plan, args.owned_only)


if __name__ == '__main__':
    try:main()
    except (OSError,ValueError,RuntimeError) as exc:sys.exit('ISO cleanup: '+str(exc))
