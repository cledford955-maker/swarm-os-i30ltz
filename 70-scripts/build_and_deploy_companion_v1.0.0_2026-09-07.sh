#!/usr/bin/env bash
# =============================================================================
#  build_and_deploy_companion  —  build the APK and install it on all 3 phones
#  Script version : 1.0.0            Date: 2026-09-07
#
#  Must run on LUCILLE itself: it needs the Android SDK, JDK 17+ and adb, and
#  it needs to see the phones. Run it, do not read it and retype it.
# =============================================================================
set -euo pipefail

PROJECT="${PROJECT:-/mnt/lucy/Luccile-v+/swarm_os-companion}"   # the v6.2.20 tree
OUT_DIR="${OUT_DIR:-/run/media/i30ltz/LUCILLE/10-releases}"
VARIANT="${VARIANT:-release}"

G='\033[0;32m'; C='\033[0;36m'; Y='\033[1;33m'; RD='\033[0;31m'; B='\033[1m'; N='\033[0m'
die() { echo -e "${RD}FATAL: $*${N}" >&2; exit 1; }

[ -d "$PROJECT" ] || die "project not found: $PROJECT (is the LUKS drive mounted?)"
cd "$PROJECT"

# ── Preflight ───────────────────────────────────────────────────────────────
echo -e "${C}${B}=== Preflight ===${N}"
command -v adb >/dev/null || die "adb not found. pacman -S android-tools"
[ -x ./gradlew ] || die "./gradlew missing in $PROJECT"

JV="$(java -version 2>&1 | head -1 | grep -oP '"\K[0-9]+' || echo 0)"
[ "$JV" -ge 17 ] || die "JDK $JV found; Android Gradle Plugin needs 17+. Set JAVA_HOME to a 17+ JDK."

SDK="$(grep -oP '^sdk.dir=\K.*' local.properties 2>/dev/null || echo "${ANDROID_HOME:-}")"
[ -n "$SDK" ] && [ -d "$SDK" ] || die "Android SDK not found. Set sdk.dir in local.properties or ANDROID_HOME."
echo -e "  ${G}OK${N} adb, gradlew, JDK $JV, SDK at $SDK"

VERSION="$(grep -oP 'versionName = "\K[^"]+' app/build.gradle.kts)"
DATE="$(date +%Y-%m-%d)"
LABEL="SWARM_OS_Companion_v${VERSION}_${DATE}"
echo -e "  building ${B}${LABEL}${N} (${VARIANT})"

# ── Build ───────────────────────────────────────────────────────────────────
echo -e "\n${C}${B}=== Build ===${N}"
if [ "$VARIANT" = "release" ]; then
    ./gradlew --no-daemon clean assembleRelease
    APK="$(find app/build/outputs/apk/release -name '*.apk' | head -1)"
else
    ./gradlew --no-daemon clean assembleDebug
    APK="$(find app/build/outputs/apk/debug -name '*.apk' | head -1)"
fi
[ -n "${APK:-}" ] && [ -f "$APK" ] || die "no APK produced"

mkdir -p "$OUT_DIR/$LABEL"
cp -f "$APK" "$OUT_DIR/$LABEL/${LABEL}.apk"
( cd "$OUT_DIR/$LABEL" && sha256sum "${LABEL}.apk" > "${LABEL}.apk.sha256" )
FINAL="$OUT_DIR/$LABEL/${LABEL}.apk"
echo -e "  ${G}OK${N} $FINAL ($(du -h "$FINAL" | cut -f1))"

# ── Devices ─────────────────────────────────────────────────────────────────
echo -e "\n${C}${B}=== Phones ===${N}"
adb start-server >/dev/null 2>&1 || true
mapfile -t DEVICES < <(adb devices | awk 'NR>1 && $2=="device" {print $1}')
UNAUTH="$(adb devices | awk 'NR>1 && $2=="unauthorized" {print $1}' | wc -l)"

[ "$UNAUTH" -gt 0 ] && echo -e "${Y}  $UNAUTH device(s) unauthorized — accept the USB-debugging prompt on the phone.${N}"

if [ "${#DEVICES[@]}" -eq 0 ]; then
    echo -e "${Y}  No phones connected.${N}"
    echo    "  USB:      plug in, enable USB debugging, accept the prompt."
    echo    "  Wireless: adb pair <ip>:<port>   then   adb connect <ip>:<port>"
    echo -e "\n  APK is ready to sideload manually: ${B}$FINAL${N}"
    exit 0
fi

echo "  found ${#DEVICES[@]} device(s): ${DEVICES[*]}"
[ "${#DEVICES[@]}" -lt 3 ] && echo -e "${Y}  Expected 3 phones — only ${#DEVICES[@]} visible.${N}"

# ── Install ─────────────────────────────────────────────────────────────────
echo -e "\n${C}${B}=== Install ===${N}"
FAILED=()
for d in "${DEVICES[@]}"; do
    MODEL="$(adb -s "$d" shell getprop ro.product.model 2>/dev/null | tr -d '\r')"
    printf "  %-22s %-18s " "$d" "$MODEL"
    if adb -s "$d" install -r -g "$FINAL" >/tmp/adb_$d.log 2>&1; then
        echo -e "${G}installed${N}"
    else
        echo -e "${RD}FAILED${N} (see /tmp/adb_$d.log)"
        FAILED+=("$d")
    fi
done

# ── Post-install: the permission Coder Droid needs ─────────────────────────
echo -e "\n${C}${B}=== All-files access (Coder Droid workspace) ===${N}"
PKG="com.aistudio.sysopt.app"
for d in "${DEVICES[@]}"; do
    case " ${FAILED[*]} " in *" $d "*) continue;; esac
    printf "  %-22s " "$d"
    # -g above grants runtime perms; MANAGE_EXTERNAL_STORAGE is special-access
    # and cannot be granted by adb install, so open the settings page instead.
    if adb -s "$d" shell appops set --uid "$PKG" MANAGE_EXTERNAL_STORAGE allow >/dev/null 2>&1; then
        echo -e "${G}granted via appops${N}"
    else
        adb -s "$d" shell am start -a android.settings.MANAGE_APP_ALL_FILES_ACCESS_PERMISSION \
            -d "package:$PKG" >/dev/null 2>&1 || true
        echo -e "${Y}opened settings on device — toggle it on${N}"
    fi
done

echo -e "\n${C}${B}======================================================================${N}"
if [ "${#FAILED[@]}" -eq 0 ]; then
    echo -e "${G}${B}  Deployed to ${#DEVICES[@]} device(s): $LABEL${N}"
else
    echo -e "${Y}${B}  Deployed to $(( ${#DEVICES[@]} - ${#FAILED[@]} ))/${#DEVICES[@]}; failed: ${FAILED[*]}${N}"
fi
echo -e "${C}${B}======================================================================${N}"
echo -e "  APK : $FINAL"
echo -e "\n  On each phone:"
echo -e "    1. Coder Droid -> folder icon -> grant All-files access if asked"
echo -e "    2. Pick the synced 30-source folder"
echo -e "    3. Remote PC -> node config -> paste the auth token from serve-to-companion.sh\n"
