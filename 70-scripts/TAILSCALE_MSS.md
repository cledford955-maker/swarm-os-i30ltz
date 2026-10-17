# Tailscale TCP packet sizing

Implemented in the ISO profile's `airootfs/etc/nftables.conf`. The live profile
enables `nftables.service` through `multi-user.target.wants`; the root installer
also enables the service and copies the profile configuration into the target.
No development-host firewall is changed by this implementation or its tests.

Tailscale documents a 1280-byte tunnel MTU. The `inet swarm_mss` table caps TCP
MSS at 1240 for IPv4 and 1220 for IPv6, accounting for IP and TCP base headers.
Only SYN packets without RST (including SYN-ACK) with an advertised MSS above
the cap are changed. Smaller advertisements, missing MSS options, established
data packets, and non-TCP traffic are unaffected. Kernel option rewriting updates
the TCP checksum.

Prerouting matches traffic arriving on `tailscale0`; postrouting matches traffic
leaving it. This covers local endpoints and subnet/exit forwarding in both
directions. The ingress cap matters when the outgoing LAN route has a larger
MTU than the tunnel. These caps assume the documented Tailscale MTU; a custom
smaller tunnel MTU needs correspondingly smaller caps. Forwarding is not enabled
by these rules.

All Tailscale interface matches use `iifname`/`oifname`, which can load before the
interface exists. The old `iif`/`oif` matches resolved an interface index during
loading and caused the entire firewall load to fail without `tailscale0`.
The existing input/forward access policies remain the same.

## Verification

Run from `/mnt/Lucy` as a normal user:

```sh
python3 70-scripts/tests/test_tailscale_mss.py
```

Requires `nft`, `ip`, `/dev/net/tun`, and permission to create user/network
namespaces. The test launches a disposable namespace before loading the full
production rules, creates fake mesh/LAN TUN devices, and sends 56 real packets.
It checks IPv4/IPv6 inbound and outbound forwarding, local mesh output, unchanged
local LAN output, SYN/SYN-ACK, small/equal MSS, ACK, SYN+RST, no MSS, and IP/TCP
checksums. It also validates loading before tunnel creation and after removal.
Namespace exit removes all test rules/devices. No sudo or Python packages needed.

Passed on the development host on 2026-09-24. This does not establish a fresh
SWARM boot or physical tailnet transfer. Tailscale itself is not included in
the current ISO package manifest; these rules become effective when its real
`tailscale0` interface is available.

On a freshly booted SWARM image, verify `systemctl is-active nftables`, inspect
`sudo nft list table inet swarm_mss`, then transfer data between actual mesh
devices and check rule counters. A zero counter is normal when the endpoints
already advertise small enough MSS. Do not reload the full configuration merely
to view it: the existing `flush ruleset` also removes dynamically installed rules
from services such as Tailscale and container networking.

Sources:
- [Tailscale TCP troubleshooting and tunnel MTU](https://tailscale.com/docs/reference/troubleshooting/network-configuration/tcp-connection-two-devices)
- [Netfilter nftables manual: interface names and TCP option rewriting](https://netfilter.org/projects/nftables/manpage.html)
