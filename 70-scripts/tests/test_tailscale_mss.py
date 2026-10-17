#!/usr/bin/env python3
"""Exercise the real staged rules using packets in a disposable network namespace.

Run as a normal user: python3 70-scripts/tests/test_tailscale_mss.py
Requires Linux user/network namespaces, nft, ip, and /dev/net/tun. No pip packages.
Never loads rules into the host network namespace.
"""
import fcntl
import os
from pathlib import Path
import select
import socket
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
RULES = ROOT / '40-iso-profile/swarm_os_iso_profile/airootfs/etc/nftables.conf'


def run(*args):
    subprocess.run(args, check=True, stdout=subprocess.DEVNULL)


def checksum(data):
    data += b'\0' * (len(data) % 2)
    total = sum(struct.unpack(f'!{len(data) // 2}H', data))
    while total >> 16:
        total = (total & 0xffff) + (total >> 16)
    return (~total) & 0xffff


def packet(version, source, dest, flags, mss, seq):
    family = socket.AF_INET if version == 4 else socket.AF_INET6
    src, dst = (socket.inet_pton(family, addr) for addr in (source, dest))
    options = b'' if mss is None else struct.pack('!BBH', 2, 4, mss)
    tcp = struct.pack('!HHIIBBHHH', 35000, 9091, seq, 1,
                      (5 + len(options) // 4) << 4, flags, 65535, 0, 0) + options
    pseudo = src + dst + (struct.pack('!BBH', 0, 6, len(tcp)) if version == 4
                          else struct.pack('!I3xB', len(tcp), 6))
    tcp = tcp[:16] + struct.pack('!H', checksum(pseudo + tcp)) + tcp[18:]
    if version == 4:
        ip = struct.pack('!BBHHHBBH4s4s', 0x45, 0, 20 + len(tcp), seq,
                         0, 64, 6, 0, src, dst)
        ip = ip[:10] + struct.pack('!H', checksum(ip)) + ip[12:]
    else:
        ip = struct.pack('!IHBB16s16s', 6 << 28, len(tcp), 6, 64, src, dst)
    return ip + tcp


def inspect(data, version, seq):
    if data[0] >> 4 != version:
        return None
    offset = 20 if version == 4 else 40
    if data[9 if version == 4 else 6] != 6 or len(data) < offset + 20:
        return None
    tcp = data[offset:]
    if struct.unpack('!I', tcp[4:8])[0] != seq:
        return None
    if version == 4:
        assert checksum(data[:20]) == 0, 'IPv4 checksum corrupted'
        pseudo = data[12:20] + struct.pack('!BBH', 0, 6, len(tcp))
    else:
        pseudo = data[8:40] + struct.pack('!I3xB', len(tcp), 6)
    assert checksum(pseudo + tcp) == 0, 'TCP checksum corrupted'
    return (None if tcp[12] >> 4 == 5 else struct.unpack('!H', tcp[22:24])[0],)


def receive(fd, version, seq):
    import time
    deadline = time.monotonic() + 2
    while time.monotonic() < deadline:
        if not select.select([fd], [], [], max(0, deadline - time.monotonic()))[0]:
            break
        result = inspect(os.read(fd, 65535), version, seq)
        if result is not None:
            return result[0]
    raise AssertionError(f'Packet {seq} did not reach the expected interface')


def main():
    # Re-exec creates isolation before any mutation; the inode check also guards
    # against someone passing the internal argument directly in the host.
    if len(sys.argv) != 3 or sys.argv[1] != '--isolated':
        host_net = os.readlink('/proc/self/ns/net')
        return subprocess.call(['unshare', '--user', '--map-root-user', '--net',
                                sys.executable, str(Path(__file__).resolve()),
                                '--isolated', host_net])
    if os.readlink('/proc/self/ns/net') == sys.argv[2]:
        raise RuntimeError('Refusing to change the original network namespace')

    # Reproduces boot before Tailscale creates its interface.
    run('nft', '-c', '-f', str(RULES))
    run('nft', '-f', str(RULES))
    print('PASS: full firewall loads before tailscale0 exists', flush=True)
    devices = {}
    for index, name in enumerate(('tailscale0', 'lan0'), 1):
        fd = os.open('/dev/net/tun', os.O_RDWR)
        fcntl.ioctl(fd, 0x400454ca, struct.pack('16sH', name.encode(), 0x0001 | 0x1000))
        devices[name] = fd
        run('ip', 'addr', 'add', f'10.{index}.0.1/24', 'dev', name)
        run('ip', '-6', 'addr', 'add', f'fd00:{index}::1/64', 'dev', name, 'nodad')
        run('ip', 'link', 'set', name, 'mtu', '1280' if index == 1 else '1500', 'up')
    for path in ('/proc/sys/net/ipv4/ip_forward', '/proc/sys/net/ipv6/conf/all/forwarding'):
        Path(path).write_text('1')
    for path in Path('/proc/sys/net/ipv4/conf').glob('*/rp_filter'):
        path.write_text('0')

    cases = [(0x02, 1460), (0x12, 1460), (0x02, 1000), (0x10, 1460),
             (0x06, 1460), (0x02, None)]
    seq = 0
    for version in (4, 6):
        cap = 1240 if version == 4 else 1220
        for direction in ('from_mesh', 'to_mesh', 'local_to_mesh', 'local_to_lan'):
            incoming, outgoing = (('tailscale0', 'lan0') if direction == 'from_mesh'
                                  else ('lan0', 'tailscale0'))
            if direction == 'local_to_lan':
                outgoing = 'lan0'
            src_index = 1 if incoming == 'tailscale0' else 2
            dst_index = 1 if outgoing == 'tailscale0' else 2
            source = f'10.{src_index}.0.2' if version == 4 else f'fd00:{src_index}::2'
            dest = f'10.{dst_index}.0.2' if version == 4 else f'fd00:{dst_index}::2'
            for flags, mss in cases + [(0x02, cap)]:
                seq += 1
                data = packet(version, source, dest, flags, mss, seq)
                if direction.startswith('local_'):
                    family = socket.AF_INET if version == 4 else socket.AF_INET6
                    with socket.socket(family, socket.SOCK_RAW, socket.IPPROTO_RAW) as sock:
                        sock.sendto(data, (dest, 0))
                else:
                    os.write(devices[incoming], data)
                expected = mss
                if direction != 'local_to_lan' and flags & 0x06 == 0x02 and mss is not None:
                    expected = min(mss, cap)
                actual = receive(devices[outgoing], version, seq)
                assert actual == expected, (version, direction, flags, mss, actual, expected)
            print(f'PASS: IPv{version} {direction} (7 packet cases + checksums)', flush=True)
    # Tunnel teardown must not make the boot configuration unloadable.
    os.close(devices['tailscale0'])
    run('nft', '-c', '-f', str(RULES))
    print(f'PASS: {seq} packet cases; firewall still validates after tunnel removal')
    return 0


if __name__ == '__main__':
    sys.exit(main())
