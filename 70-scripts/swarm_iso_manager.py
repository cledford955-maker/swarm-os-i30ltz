#!/usr/bin/env python3
"""Single Ventoy release store. Stable is always an explicit human decision."""
import argparse
import contextlib
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

STORE = Path('/mnt/ventoy/ISO/SWARM_OS')
MOUNT = Path('/mnt/ventoy')
PROJECT = Path('/mnt/Lucy')
ISO_RE = re.compile(r'^swarm[-_]os[-_]v?\d.*\.iso$', re.I)
KEEP = 10

def require_store():
    mount = json.loads(subprocess.check_output(['findmnt','--json','--mountpoint',str(MOUNT),'-o','TARGET,UUID,FSTYPE'],text=True))['filesystems'][0]
    if mount['uuid'].upper() != '4E21-0000' or mount['fstype'] != 'exfat':
        raise RuntimeError('Expected Ventoy data partition is not mounted at /mnt/ventoy.')
    if STORE.resolve() != STORE:
        raise RuntimeError('ISO directory must not redirect through a symlink.')
    return STORE

def atomic_text(path, value):
    tmp = path.with_name(path.name+'.tmp')
    with tmp.open('w') as f:
        f.write(value); f.flush(); os.fsync(f.fileno())
    tmp.replace(path)

def digest(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for b in iter(lambda:f.read(8*1024*1024),b''): h.update(b)
    return h.hexdigest()

def releases(store):
    return sorted((p for p in store.glob('*.iso') if not p.is_symlink() and ISO_RE.fullmatch(p.name)),key=lambda p:(p.stat().st_mtime_ns,p.name),reverse=True)

def stable(p):
    return p.with_name(p.name+'.stable').exists() or bool(re.search(r'(^|[-_.])stable([-_.]|$)',p.stem,re.I))

def status(p):
    side=p.with_name(p.name+'.json')
    return json.loads(side.read_text()).get('boot_gate','untested') if side.exists() else 'untested'

def latest(store):
    pointer=store/'latest.txt'
    if pointer.exists():
        name=pointer.read_text().strip()
        if Path(name).name == name and ISO_RE.fullmatch(name):
            p=store/name
            if p.is_file() and not p.is_symlink() and status(p) != 'failed': return p
    for p in releases(store):
        if status(p) != 'failed': return p
    raise RuntimeError('No usable SWARM ISO in Ventoy. Build or migrate one first.')

def update_latest(store):
    try: candidate=latest(store)
    except RuntimeError:
        (store/'latest.txt').unlink(missing_ok=True);return
    atomic_text(store/'latest.txt',candidate.name+'\n')

def prune(store,dry_run=False):
    rolling=[p for p in releases(store) if not stable(p)]
    removed=rolling[KEEP:]
    for p in removed:
        print(('Would remove ' if dry_run else 'Removing ')+p.name)
        if not dry_run:
            p.unlink()
            for suffix in ['.json','.sha256']:
                p.with_name(p.name+suffix).unlink(missing_ok=True)
    if not dry_run: update_latest(store)
    return removed

def publish(store,source,name,result):
    if not ISO_RE.fullmatch(name) or Path(name).name != name: raise ValueError('Invalid versioned ISO name')
    source=source.resolve(strict=True)
    if not source.is_relative_to(store/'.incoming'): raise ValueError('Build output must be inside Ventoy .incoming')
    target=store/name
    if target.exists(): raise FileExistsError(target)
    checksum=digest(source)
    source.replace(target)
    atomic_text(target.with_name(name+'.sha256'),f'{checksum}  {name}\n')
    atomic_text(target.with_name(name+'.json'),json.dumps({'boot_gate':result,'published':time.strftime('%Y-%m-%dT%H:%M:%S%z')},indent=2)+'\n')
    if result != 'failed': atomic_text(store/'latest.txt',name+'\n')
    prune(store)
    print(target)

def migrate(store,sources,dry_run=False):
    # Move only recognized SWARM releases; never touch other operating systems.
    for source in sources:
        if source.is_symlink() or not source.is_file() or not ISO_RE.fullmatch(source.name): continue
        if source.parent == store: continue
        target=store/source.name
        print(('Would migrate ' if dry_run else 'Migrating ')+str(source),flush=True)
        if dry_run: continue
        source_hash=digest(source)
        if target.exists():
            if digest(target) != source_hash: raise RuntimeError(f'Different ISOs share the same name: {source.name}; leaving both intact.')
        else:
            temp=store/(source.name+'.partial')
            if temp.exists(): raise RuntimeError(f'Interrupted copy exists: {temp}; inspect before retry.')
            shutil.copyfile(source,temp)
            if digest(temp) != source_hash: raise RuntimeError(f'Copy verification failed: {source}')
            with temp.open('rb') as f: os.fsync(f.fileno())
            shutil.copystat(source,temp)
            temp.replace(target)
        for suffix in ['.stable','.json']:
            side=source.with_name(source.name+suffix)
            if side.exists():
                dest=target.with_name(target.name+suffix)
                if dest.exists() and dest.read_bytes()!=side.read_bytes():
                    raise RuntimeError(f'Conflicting release metadata: {side}; leaving original intact.')
                shutil.copyfile(side,dest)
        atomic_text(target.with_name(target.name+'.sha256'),f'{source_hash}  {target.name}\n')
        source.unlink()
        for suffix in ['.stable','.json','.sha256']: source.with_name(source.name+suffix).unlink(missing_ok=True)
    if not dry_run:
        # Remove old full-size latest/fallback aliases only after proving an
        # identical, versioned release exists. Never infer that fallback is stable.
        for alias in [store/'swarm-os-latest.iso',store/'swarm-os-fallback.iso']:
            if alias.is_file() and not alias.is_symlink() and not stable(alias):
                same_size=[p for p in releases(store) if p.stat().st_size==alias.stat().st_size]
                ah=digest(alias)
                if any(digest(p)==ah for p in same_size):
                    print('Removing verified duplicate '+str(alias));alias.unlink()
                else: print('Unmatched legacy alias retained for review: '+str(alias))
        available=[p for p in releases(store) if status(p)!='failed']
        if available: atomic_text(store/'latest.txt',available[0].name+'\n')
        prune(store)

def migration_sources():
    roots=[PROJECT/'10-releases',Path('/home/i30ltz/Desktop'),MOUNT,MOUNT/'SWARM-OS',MOUNT/'SWARM_OS']
    result=[]
    for root in roots:
        if root.exists():
            result.extend(root.rglob('*.iso') if root==PROJECT/'10-releases' else root.glob('*.iso'))
    return sorted(set(result))

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    subs=parser.add_subparsers(dest='command',required=True)
    for name in ['check','latest','list']: subs.add_parser(name)
    for name in ['prune','migrate']:
        sub=subs.add_parser(name);sub.add_argument('--dry-run',action='store_true')
    for name in ['stable','unmark-stable']:
        sub=subs.add_parser(name);sub.add_argument('iso');sub.add_argument('--note',default='Explicitly marked stable by user')
    sub=subs.add_parser('publish');sub.add_argument('source',type=Path);sub.add_argument('name');sub.add_argument('--result',choices=['pass','failed','untested'],required=True)
    args=parser.parse_args();store=require_store()
    if args.command=='check': print(store);return
    if args.command=='latest': print(latest(store));return
    if args.command=='list':
        for p in releases(store): print(('STABLE' if stable(p) else 'rolling')+'\t'+status(p)+'\t'+p.name)
        return
    if not store.exists(): store.mkdir(parents=True)
    # Lock lives on local ext4: exFAT has no symlinks, and latest is a text pointer.
    lock=PROJECT/'70-scripts/.iso-manager.lock'
    with lock.open('a') as f:
        fcntl.flock(f,fcntl.LOCK_EX)
        if args.command=='prune': prune(store,args.dry_run)
        elif args.command=='migrate': migrate(store,migration_sources(),args.dry_run)
        elif args.command=='publish': publish(store,args.source,args.name,args.result)
        else:
            p=store/Path(args.iso).name
            if not p.is_file() or p.is_symlink() or not ISO_RE.fullmatch(p.name): raise ValueError('Choose an existing versioned SWARM ISO')
            marker=p.with_name(p.name+'.stable')
            if args.command=='stable': atomic_text(marker,args.note+'\n');print('Protected: '+p.name)
            else:
                if re.search(r'(^|[-_.])stable([-_.]|$)',p.stem,re.I): raise ValueError('Rename the ISO to remove its stable label first.')
                marker.unlink(missing_ok=True);print('No longer pinned: '+p.name)

if __name__=='__main__':
    try: main()
    except (OSError,ValueError,RuntimeError,subprocess.CalledProcessError,IndexError,KeyError) as exc:
        sys.exit('ISO manager: '+str(exc))
