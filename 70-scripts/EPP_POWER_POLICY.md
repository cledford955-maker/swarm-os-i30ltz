# SWARM automatic CPU power preference

SWARM checks CPU energy/performance preference (EPP) 30 seconds after boot and
every 20 seconds thereafter. No CPU governor, frequency limit, boost setting,
thermal limit or GPU setting is changed.

- AC power, or a desktop without a system battery: `balance_performance`.
- Present system battery without an online external supply: `balance_power`.
- Peripheral batteries (mouse/headset) do not select the battery policy.
- Unsupported CPUs or preferences are skipped without guessing another value.
- An explicit `performance` governor is respected.
- Active power-profiles-daemon, TLP, tuned, auto-cpufreq or cpupower services take
  precedence; SWARM makes no writes while one is active.

The implementation uses each policy's kernel-provided
`energy_performance_available_preferences` list and verifies each changed value
by reading it back. Kernel references:

- https://docs.kernel.org/admin-guide/pm/intel_pstate.html
- https://docs.kernel.org/admin-guide/pm/amd-pstate.html

## Runtime controls

Read-only inspection on SWARM:

```sh
/usr/lib/swarm/epp-tune.sh --status
systemctl status swarm-epp.timer
journalctl -u swarm-epp.service -b
```

Defaults are in `/etc/default/swarm-epp`. Supported configuration values are
`default`, `performance`, `balance_performance`, `balance_power`, and `power`;
they are applied only when advertised by the CPU driver. A configuration change
is picked up on the next timer invocation. Invalid configuration fails visibly
in the journal.

To stop automatic selection on SWARM, an administrator can run:

```sh
sudo systemctl disable --now swarm-epp.timer
```

Stopping the timer leaves the last selected preference in place. A separate
power manager can then set its own policy.

## Build and validation

The script, configuration, service, timer and enabling symlink live directly in
`40-iso-profile/swarm_os_iso_profile/airootfs/`. `profiledef.sh` sets root ownership
and executable permissions. The existing ISO root filesystem and installer
archive flows carry these files and the timer symlink into the live and installed
systems. No extra package or backend is required.

`70-scripts/tests/test_epp_tune.py` uses temporary sysfs fixtures and a fake
systemctl; tests do not alter the development host's CPU settings. `--sysfs`
is provided for this fixture testing. Runtime service execution always uses
real `/sys`.

```sh
python3 -m unittest discover -s 70-scripts/tests -p test_epp_tune.py
```

A new ISO boot is still required to verify timer activation and real hardware
writes under the service's restrictions. Development-host status inspection is
not that boot test.
