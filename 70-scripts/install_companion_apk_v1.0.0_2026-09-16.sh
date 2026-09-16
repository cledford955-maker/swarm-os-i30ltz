#!/bin/bash
# install_companion_apk v1.0.0 — 2026-09-16
#
# Installs the SWARM OS companion APK on every phone connected by USB (wired
# adb) and checks each one can actually use the remote terminal afterwards.
#
#   bash 70-scripts/install_companion_apk_v1.0.0_2026-09-16.sh           # check + install
#   bash 70-scripts/install_companion_apk_v1.0.0_2026-09-16.sh --check   # check only, install nothing
#
# Per phone it reports: model, installed version, whether the phone reaches
# LUCILLE's LucyServer over Tailscale, and whether its saved token matches
# LUCILLE's (compared by hash — the token is never printed).
#
# It never uninstalls. If Android refuses the update because the installed
# copy was signed with a different key, the script says so and moves on;
# uninstalling would wipe the phone's tasks, chats and memory, so that stays
# a deliberate manual step.
set -euo pipefail

ADB="${ADB:-$HOME/Android/Sdk/platform-tools/adb}"
PKG="com.aistudio.sysopt.app"
APK="/mnt/Lucy/30-source/android_companion/swarm_os-companion/app/build/outputs/apk/debug/app-debug.apk"
HOST="${SWARM_HOST:-100.82.1.19}"   # LUCILLE on CachyOS (tailscale status)
PORT="${SWARM_PORT:-5000}"
TOKEN_FILE="${SWARM_TOKEN_FILE:-$HOME/.config/swarm/auth.env}"
CHECK_ONLY=0
[ "${1:-}" = "--check" ] && CHECK_ONLY=1

command -v "$ADB" >/dev/null 2>&1 || ADB=adb
[ -f "$APK" ] || { echo "APK not found: $APK — build it first (gradle assembleDebug)."; exit 1; }

hash12() { printf %s "$1" | sha256sum | cut -c1-12; }
LUCILLE_TOKEN=""
if [ -r "$TOKEN_FILE" ]; then
  LUCILLE_TOKEN=$(grep -m1 '^SWARM_AUTH_TOKEN=' "$TOKEN_FILE" | cut -d= -f2- | tr -d "\"'")
fi

APK_VERSION=$(unzip -p "$APK" AndroidManifest.xml >/dev/null 2>&1 && "$HOME"/Android/Sdk/build-tools/*/aapt2 dump badging "$APK" 2>/dev/null | sed -n "s/.*versionName='\([^']*\)'.*/\1/p" | head -1 || true)
echo "APK:     $APK (${APK_VERSION:-version unknown})"
echo "LUCILLE: $HOST:$PORT"
echo

mapfile -t LINES < <("$ADB" devices | tail -n +2 | grep -v '^\s*$' || true)
if [ ${#LINES[@]} -eq 0 ]; then
  echo "No phones found. Plug each phone in by USB, enable Developer options → USB debugging,"
  echo "then accept the 'Allow USB debugging?' prompt on the phone and run this again."
  exit 1
fi

ok=0; failed=0
for line in "${LINES[@]}"; do
  serial=$(awk '{print $1}' <<<"$line"); state=$(awk '{print $2}' <<<"$line")
  if [ "$state" != "device" ]; then
    echo "== $serial: $state — unlock the phone and accept the USB debugging prompt, then re-run."
    failed=$((failed+1)); continue
  fi
  a() { "$ADB" -s "$serial" "$@"; }
  model=$(a shell getprop ro.product.model | tr -d '\r')
  before=$(a shell dumpsys package "$PKG" | sed -n 's/.*versionName=//p' | head -1 | tr -d '\r')
  echo "== $model ($serial) — installed: ${before:-not installed}"

  if [ $CHECK_ONLY -eq 0 ]; then
    if out=$(a install -r "$APK" 2>&1); then
      after=$(a shell dumpsys package "$PKG" | sed -n 's/.*versionName=//p' | head -1 | tr -d '\r')
      echo "   install: OK → $after"
    else
      echo "   install: FAILED — $(tail -1 <<<"$out")"
      if grep -q UPDATE_INCOMPATIBLE <<<"$out"; then
        echo "   The installed app was signed with a different key. Uninstalling first would erase this phone's"
        echo "   tasks, chats and memory — do it by hand only if that's acceptable: adb -s $serial uninstall $PKG"
      fi
      failed=$((failed+1)); continue
    fi
  fi

  if a shell "toybox nc -z -w 4 $HOST $PORT" >/dev/null 2>&1; then
    echo "   tailscale → LucyServer: reachable"
  else
    echo "   tailscale → LucyServer: NOT reachable — open the Tailscale app on this phone and connect."
  fi

  prefs=$(a shell run-as "$PKG" cat shared_prefs/swarm_connection.xml 2>/dev/null | tr -d '\r' || true)
  phone_host=$(sed -n 's/.*name="host">\([^<]*\)<.*/\1/p' <<<"$prefs")
  phone_token=$(sed -n 's/.*name="auth_token">\([^<]*\)<.*/\1/p' <<<"$prefs")
  echo "   saved host: ${phone_host:-default ($HOST in v6.2.12)}"
  if [ -z "$LUCILLE_TOKEN" ]; then
    echo "   token: can't compare ($TOKEN_FILE not readable)"
  elif [ -z "$phone_token" ] || [ "$phone_token" = "swarm-token-2026" ]; then
    echo "   token: default — enter LUCILLE's token under Remote PC → CHANGE NODE"
  elif [ "$(hash12 "$phone_token")" = "$(hash12 "$LUCILLE_TOKEN")" ]; then
    echo "   token: matches LUCILLE"
  else
    echo "   token: DOES NOT match LUCILLE — re-enter it under Remote PC → CHANGE NODE"
  fi
  ok=$((ok+1))
done

echo
echo "$ok phone(s) ready, $failed need attention."
[ $failed -eq 0 ]
