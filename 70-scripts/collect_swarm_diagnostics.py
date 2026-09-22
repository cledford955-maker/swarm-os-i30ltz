#!/usr/bin/env python3
"""Collect bounded, read-only SWARM diagnostics without sudo or uploads."""
import argparse
import datetime as dt
import io
import json
import os
from pathlib import Path
import re
import subprocess
import tarfile
import tempfile
import urllib.error
import urllib.request

LIMIT = 128 * 1024
SERVICES = ('lucy-server', 'gaming-agent', 'swarm-ui', 'swarm-secrets')


def redact(text):
    # Whole sensitive assignment values, including quoted values with spaces.
    text = re.sub(
        r'''(?im)(?<![\w.-])(["']?[\w.-]*(?:api[_-]?key|token|secret|password|passwd|authorization|cookie)[\w.-]*["']?\s*[:=]\s*)("[^"\n]*"|'[^'\n]*'|[^\n,;}]+)''',
        r'\1[REDACTED]', text)
    text = re.sub(r'(?i)\b(Bearer|Basic)\s+[A-Za-z0-9._~+/=-]+', r'\1 [REDACTED]', text)
    text = re.sub(r'(?i)(https?://)[^\s/@]+:[^\s/@]+@', r'\1[REDACTED]@', text)
    text = re.sub(r'\b(?:sk-[A-Za-z0-9_-]{8,}|gh[pousr]_[A-Za-z0-9_]{8,}|github_pat_[A-Za-z0-9_]{8,})\b', '[REDACTED]', text)
    text = re.sub(r'-----BEGIN [^-]*PRIVATE KEY-----.*?(?:-----END [^-]*PRIVATE KEY-----|\Z)', '[REDACTED PRIVATE KEY]', text, flags=re.S)
    return text


def collect_command(argv, timeout=10):
    # A file sink prevents a noisy command from exhausting collector memory.
    with tempfile.TemporaryFile() as output:
        try:
            proc = subprocess.Popen(argv, stdout=output, stderr=subprocess.STDOUT,
                                    env={**os.environ, 'LC_ALL': 'C', 'SYSTEMD_PAGER': 'cat'})
        except OSError as exc:
            return {'command': argv, 'error': str(exc)}
        timed_out = False
        try:
            proc.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            timed_out = True
            proc.kill()
            proc.wait()
        size = output.tell()
        output.seek(0)
        body = output.read(LIMIT).decode('utf-8', errors='replace')
    return {'command': argv, 'exit_code': proc.returncode, 'timed_out': timed_out,
            'truncated': size > LIMIT, 'output': redact(body)}


def health(port):
    url = f'http://127.0.0.1:{port}/health'
    # Do not send localhost diagnostics through proxy settings or redirects.
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, headers, newurl):
            return None
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
    try:
        with opener.open(url, timeout=3) as response:
            body = response.read(LIMIT + 1)
            return {'url': url, 'status': response.status, 'truncated': len(body) > LIMIT,
                    'body': redact(body[:LIMIT].decode('utf-8', errors='replace'))}
    except (OSError, urllib.error.URLError) as exc:
        return {'url': url, 'error': str(exc)}


def collect(include_journal=False):
    report = {'created_utc': dt.datetime.now(dt.timezone.utc).isoformat(),
              'scope': 'This machine only; not an ISO boot or installed-target verification.',
              'journal_included': include_journal, 'commands': {}, 'health': {}}
    commands = {
        'kernel': ['uname', '-srmo'],
        'disks': ['lsblk', '-J', '-o', 'NAME,TYPE,SIZE,FSTYPE,MOUNTPOINTS,RO'],
        'space': ['df', '-h', '/'],
        'memory': ['free', '-h'],
        'failed_units': ['systemctl', '--no-pager', '--failed'],
    }
    for service in SERVICES:
        commands[service] = ['systemctl', 'show', service + '.service', '--no-pager',
                             '--property=Id,LoadState,ActiveState,SubState,Result,ExecMainStatus']
    for service in ('swarm-lucy-dev', 'swarm-gaming-dev'):
        commands[service] = ['systemctl', '--user', 'show', service + '.service', '--no-pager',
                             '--property=Id,LoadState,ActiveState,SubState,Result,ExecMainStatus']
    if include_journal:
        for service in SERVICES:
            commands[service + '_journal'] = ['journalctl', '--no-pager', '-b', '-n', '150',
                                               '-o', 'short-iso', '-u', service + '.service']
    for name, argv in commands.items():
        report['commands'][name] = collect_command(argv)
    for name, path in [('os_release', Path('/etc/os-release')),
                       ('project_version', (Path('/etc/swarm-release') if Path('/etc/swarm-release').exists() else Path('/mnt/Lucy/VERSION')))]:
        try:
            with path.open() as source:
                report[name] = redact(source.read(LIMIT))
        except OSError as exc:
            report[name] = {'error': str(exc)}
    for port in (5000, 8401):
        report['health'][str(port)] = health(port)
    return report


def write_bundle(report, output_dir):
    output_dir.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now(dt.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    fd, name = tempfile.mkstemp(prefix=f'swarm-diagnostics-{stamp}-', suffix='.tar.gz', dir=output_dir)
    # mkstemp creates mode 0600; no staging directory or raw logs remain behind.
    with os.fdopen(fd, 'wb') as destination:
        with tarfile.open(fileobj=destination, mode='w:gz') as archive:
            entries = {
                'report.json': json.dumps(report, indent=2),
                'README.txt': ('SWARM local diagnostics\n\nRead report.json for results and command failures.\n'
                               'Missing permissions or tools are recorded, not hidden.\n'
                               'No environment files, process environments, or source trees are collected.\n'
                               'Credential redaction is best effort. Review before sharing, especially journals.\n'
                               'Hostnames, paths, disk layout, and application messages may identify this machine.\n'
                               'This archive is local only; nothing was uploaded.\n'),
            }
            for entry, content in entries.items():
                data = content.encode()
                info = tarfile.TarInfo(entry)
                info.size, info.mode = len(data), 0o600
                archive.addfile(info, io.BytesIO(data))
    return Path(name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path,
                        default=Path.home() / 'swarm-diagnostics')
    parser.add_argument('--include-journal', action='store_true',
                        help='Include the last 150 current-boot lines per SWARM system service (review before sharing).')
    args = parser.parse_args()
    print(write_bundle(collect(args.include_journal), args.output_dir))


if __name__ == '__main__':
    main()
