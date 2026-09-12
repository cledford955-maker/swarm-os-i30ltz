#!/usr/bin/env bash
# =============================================================================
# seal_secrets.sh — SWARM OS sealed secrets  v1.0.0 · 2026-09-12
#
# WHY THIS EXISTS
# Until 2026-09-12 the build did this:
#     sed 's|\\$||' 20-runtime/.env > airootfs/etc/swarm_os.env
# — every API key you own, in plaintext, inside every ISO. Anyone who booted
# one, mounted one, or was handed one on a USB stick had all of them. That is
# now removed. The ISO carries only an encrypted blob; the passphrase never
# leaves your head or your key file.
#
# WHAT IT PRODUCES
#   airootfs/etc/swarm_os.env.gpg       AES-256 symmetric, no plaintext
#   airootfs/etc/swarm_os.env.manifest  key NAMES only — what is sealed, no values
#
# The matching unsealer is /usr/local/bin/swarm-unseal-secrets inside the ISO.
#
# USAGE
#   ./seal_secrets.sh                     # prompts for the passphrase twice
#   SWARM_SECRETS_PASSPHRASE=… ./seal_secrets.sh    # unattended (CI)
# =============================================================================
set -euo pipefail

LUCY="/mnt/Lucy"
SRC_ENV="${SWARM_ENV_FILE:-$LUCY/20-runtime/.env}"
AIROOTFS="${1:-$LUCY/40-iso-profile/swarm_os_iso_profile/airootfs}"
OUT_BLOB="$AIROOTFS/etc/swarm_os.env.gpg"
OUT_MANIFEST="$AIROOTFS/etc/swarm_os.env.manifest"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
fail() { echo -e "${RED}✗ $*${NC}" >&2; exit 1; }
ok()   { echo -e "${GREEN}✓ $*${NC}"; }

command -v gpg >/dev/null 2>&1 || fail "gpg not found (pacman -S gnupg)"
[ -f "$SRC_ENV" ] || fail "No source env at $SRC_ENV"

umask 077
TMP="$(mktemp -d -t swarm-seal-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

# Normalise exactly as the old bake did: drop comments, blanks, and the
# backslash line-continuations that break `set -a` sourcing.
sed 's|\\$||' "$SRC_ENV" | grep -v '^[[:space:]]*#' | grep -v '^[[:space:]]*$' > "$TMP/plain.env"
VARS=$(grep -cE '^[A-Za-z_][A-Za-z0-9_]*=' "$TMP/plain.env" || true)
[ "$VARS" -gt 0 ] || fail "$SRC_ENV yielded no variables — refusing to seal an empty blob"

# --- passphrase --------------------------------------------------------------
if [ -n "${SWARM_SECRETS_PASSPHRASE:-}" ]; then
    printf '%s' "$SWARM_SECRETS_PASSPHRASE" > "$TMP/pass"
    echo -e "${YELLOW}  using SWARM_SECRETS_PASSPHRASE from the environment${NC}"
else
    echo -e "${CYAN}Sealing $VARS variables from $SRC_ENV${NC}"
    read -rsp "  Passphrase: " P1; echo
    read -rsp "  Again:      " P2; echo
    [ "$P1" = "$P2" ] || fail "Passphrases do not match"
    [ ${#P1} -ge 12 ] || fail "Use at least 12 characters — this unlocks every key you own"
    printf '%s' "$P1" > "$TMP/pass"
    unset P1 P2
fi

# --- seal --------------------------------------------------------------------
mkdir -p "$AIROOTFS/etc"
rm -f "$OUT_BLOB"
gpg --batch --yes --quiet \
    --symmetric --cipher-algo AES256 --digest-algo SHA512 \
    --s2k-mode 3 --s2k-count 65011712 --s2k-digest-algo SHA512 \
    --passphrase-file "$TMP/pass" --pinentry-mode loopback \
    --output "$OUT_BLOB" "$TMP/plain.env" \
    || fail "gpg refused to encrypt"
chmod 0600 "$OUT_BLOB"

# --- prove it round-trips before we call it done ------------------------------
gpg --batch --quiet --decrypt --passphrase-file "$TMP/pass" --pinentry-mode loopback \
    "$OUT_BLOB" > "$TMP/check.env" 2>/dev/null || fail "Sealed blob does not decrypt with the passphrase just given"
cmp -s "$TMP/plain.env" "$TMP/check.env" || fail "Round-trip mismatch — the blob is corrupt, do not ship it"
ok "round-trip verified: seals and unseals cleanly"

# --- manifest: names only, never values --------------------------------------
{
    echo "# SWARM OS sealed-secret manifest — NAMES ONLY, no values."
    echo "# v1.0.0 · sealed $(date +%Y-%m-%d\ %H:%M:%S\ %Z)"
    echo "# Tells you what is inside swarm_os.env.gpg without decrypting it."
    echo "#"
    grep -oE '^[A-Za-z_][A-Za-z0-9_]*' "$TMP/plain.env" | sort -u
} > "$OUT_MANIFEST"
chmod 0644 "$OUT_MANIFEST"

# --- refuse to finish if plaintext is still sitting in the ISO ----------------
if [ -f "$AIROOTFS/etc/swarm_os.env" ]; then
    fail "Plaintext $AIROOTFS/etc/swarm_os.env still exists. Delete it — sealing is
       pointless while the cleartext copy is right next to the blob."
fi

echo
ok "sealed $VARS variables -> $OUT_BLOB ($(stat -c%s "$OUT_BLOB") bytes, AES-256)"
ok "manifest (names only)  -> $OUT_MANIFEST"
echo -e "${YELLOW}  The passphrase is not stored anywhere. Lose it and the ISO has no keys.${NC}"
