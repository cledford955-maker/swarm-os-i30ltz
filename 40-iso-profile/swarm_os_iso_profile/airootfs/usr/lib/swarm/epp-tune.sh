#!/usr/bin/env bash
# SWARM automatic EPP selection. CPU governors, frequencies and boost are untouched.
set -euo pipefail
shopt -s nullglob

mode=apply
sysfs=/sys
while (($#)); do
    case "$1" in
        --status) mode=status; shift ;;
        --sysfs) [[ $# -ge 2 ]] || { echo '--sysfs needs a directory' >&2; exit 2; }; sysfs=$2; shift 2 ;;
        --help) echo 'Usage: epp-tune.sh [--status] [--sysfs DIRECTORY]'; exit 0 ;;
        *) echo "Unknown argument: $1" >&2; exit 2 ;;
    esac
done
[[ -d "$sysfs" ]] || { echo "Missing sysfs directory: $sysfs" >&2; exit 2; }

# Do not fight a user's existing power-management policy.
manager=none
for unit in power-profiles-daemon.service tlp.service tuned.service auto-cpufreq.service cpupower.service; do
    if systemctl is-active --quiet "$unit" 2>/dev/null; then
        manager=$unit
        break
    fi
done
if [[ "$manager" != none ]]; then
    echo "EPP: delegated to $manager; no changes"
    exit 0
fi

battery=0
online=0
for supply in "$sysfs"/class/power_supply/*; do
    [[ -r "$supply/type" ]] || continue
    kind=$(<"$supply/type")
    # Ignore peripheral (mouse/headset) batteries.
    if [[ -r "$supply/scope" && $(<"$supply/scope") == Device ]]; then continue; fi
    if [[ "$kind" == Battery ]]; then
        if [[ ! -r "$supply/present" || $(<"$supply/present") == 1 ]]; then battery=1; fi
    elif [[ -r "$supply/online" && $(<"$supply/online") == 1 ]]; then
        online=1
    fi
done
power=ac
if ((battery && !online)); then power=battery; fi
if [[ "$power" == battery ]]; then
    wanted=${SWARM_EPP_BATTERY:-balance_power}
else
    wanted=${SWARM_EPP_AC:-balance_performance}
fi
case "$wanted" in
    default|performance|balance_performance|balance_power|power) ;;
    *) echo "Invalid EPP preference: $wanted" >&2; exit 2 ;;
esac

policies=("$sysfs"/devices/system/cpu/cpufreq/policy*/energy_performance_preference)
if ((${#policies[@]} == 0)); then
    echo 'EPP: unsupported by this CPU/driver; no changes'
    exit 0
fi
errors=0
for preference in "${policies[@]}"; do
    policy=${preference%/*}
    label=${policy##*/}
    available="$policy/energy_performance_available_preferences"
    if [[ ! -r "$preference" || ! -r "$available" ]]; then
        echo "EPP: $label preference unavailable; skipped"
        continue
    fi
    current=$(<"$preference")
    choices=" $(tr '\n\t' '  ' < "$available") "
    selected=$wanted
    if [[ "$choices" != *" $selected "* ]]; then
        echo "EPP: $label does not support $selected; keeping $current"
        continue
    fi
    # A performance governor can forbid non-performance EPP. Respect it.
    if [[ -r "$policy/scaling_governor" && $(<"$policy/scaling_governor") == performance && "$selected" != performance ]]; then
        echo "EPP: $label has performance governor; keeping $current"
        continue
    fi
    if [[ "$mode" == status ]]; then
        echo "EPP: $label power=$power current=$current target=$selected (read-only)"
    elif [[ "$current" != "$selected" ]]; then
        if printf '%s\n' "$selected" > "$preference"; then
            actual=$(<"$preference")
            if [[ "$actual" == "$selected" ]]; then
                echo "EPP: $label power=$power $current -> $actual"
            else
                echo "EPP: $label requested $selected but read back $actual" >&2
                errors=1
            fi
        else
            echo "EPP: failed to write $label" >&2
            errors=1
        fi
    fi
done
exit "$errors"
