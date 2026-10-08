#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════╗
# ║  scan-secrets.sh — find live API keys anywhere in the project        ║
# ║  Version: 1.0.0 | Date: 2026-10-05                                   ║
# ║                                                                      ║
# ║  There is exactly ONE place secrets belong:                          ║
# ║      /mnt/Lucy/20-runtime/.env                                       ║
# ║  Anything this finds outside that file is a leak waiting to happen.  ║
# ║                                                                      ║
# ║  Read-only. It never edits or deletes; it tells you where to look.   ║
# ║                                                                      ║
# ║    bash scan-secrets.sh            # scan /mnt/Lucy                  ║
# ║    bash scan-secrets.sh --quiet    # only findings, for a git hook   ║
# ║  Exit 0 = clean, 1 = findings.                                       ║
# ╚══════════════════════════════════════════════════════════════════════╝
set -uo pipefail

ROOT="${SCAN_ROOT:-/mnt/Lucy}"
CANONICAL="${SWARM_ENV_FILE:-/mnt/Lucy/20-runtime/.env}"
QUIET=0
[[ "${1:-}" == "--quiet" ]] && QUIET=1

C_RED=$'\033[0;31m'; C_YEL=$'\033[1;33m'; C_GRN=$'\033[0;32m'
C_CYN=$'\033[0;36m'; C_DIM=$'\033[2m';   C_NC=$'\033[0m'

say()  { [[ $QUIET -eq 0 ]] && echo "$@"; return 0; }
head2(){ say ""; say "${C_CYN}── $* ${C_NC}"; }

say ""
say "  scan-secrets v1.0.0   root: $ROOT"
say "  canonical secrets file: $CANONICAL"

# Real key shapes, not the word "key". Keeps the false-positive rate low
# enough that the output is worth reading.
PATTERNS=(
  'sk-or-v1-[A-Za-z0-9]{32,}'      # OpenRouter
  'sk-proj-[A-Za-z0-9_-]{20,}'     # OpenAI project
  'sk-ant-[A-Za-z0-9_-]{20,}'      # Anthropic
  'sk-[A-Za-z0-9]{32,}'            # generic OpenAI-style
  'nvapi-[A-Za-z0-9_-]{20,}'       # NVIDIA
  'AIza[A-Za-z0-9_-]{30,}'         # Google
  'gsk_[A-Za-z0-9]{20,}'           # Groq
  'ghp_[A-Za-z0-9]{30,}'           # GitHub PAT
  'github_pat_[A-Za-z0-9_]{30,}'
  'xox[baprs]-[A-Za-z0-9-]{10,}'   # Slack
  'AKIA[0-9A-Z]{16}'               # AWS access key id
)

# Directories with nothing to protect, and plenty to false-positive on.
PRUNE=(
  -name .git -o -name node_modules -o -name .gradle -o -name .dart_tool
  -o -name obj -o -name .kotlin -o -name .idea -o -name flutter-sdk
  -o -name vosk-model-cache -o -name .Trash-1000 -o -name lost+found
  -o -name _to_delete -o -name 99-archive
)

FOUND=0
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT

head2 "Live key material outside the canonical file"
for pattern in "${PATTERNS[@]}"; do
  find "$ROOT" \( "${PRUNE[@]}" \) -prune -o -type f -size -2M -print 2>/dev/null \
    | while IFS= read -r file; do
        [[ "$file" == "$CANONICAL" ]] && continue
        [[ "$file" == *.tmp ]] && continue
        if grep -lqsaE "$pattern" "$file" 2>/dev/null; then
          echo "$file" >> "$TMP"
        fi
      done
done

if [[ -s "$TMP" ]]; then
  sort -u "$TMP" | while IFS= read -r file; do
    FOUND=1
    echo "${C_RED}  LEAK${C_NC}  $file"
    # Show the variable name and a short prefix only — never the whole key.
    grep -onaE "[A-Za-z_]*([Kk][Ee][Yy]|[Tt][Oo][Kk][Ee][Nn])[A-Za-z_]*[\"' ]*[:=][\"' ]*[A-Za-z0-9_-]{6}" \
      "$file" 2>/dev/null | head -3 | sed "s|^|        ${C_DIM}|; s|\$|…${C_NC}|"
  done
  # the subshell above cannot set FOUND, so re-derive it
  FOUND=1
else
  say "${C_GRN}  none${C_NC}"
fi

head2 "Files that are *shaped* like secret stores (check these by hand)"
STORES=0
while IFS= read -r file; do
  [[ "$file" == "$CANONICAL" ]] && continue
  STORES=1
  printf '%s  %s%s\n' "${C_YEL}  CHECK${C_NC}" "$file" ""
done < <(find "$ROOT" \( "${PRUNE[@]}" \) -prune -o -type f \
          \( -name '.env' -o -name '.env.*' -o -name '*.env' \
             -o -name 'appsettings*.json' -o -name 'secrets*.json' \
             -o -name '*password*.txt' -o -name '*token*.txt' \
             -o -name 'local.properties' \) -print 2>/dev/null | sort)
[[ $STORES -eq 0 ]] && say "${C_GRN}  none${C_NC}"

head2 "Build output holding a secrets file (the old bug's signature)"
BUILDLEAK=0
while IFS= read -r file; do
  BUILDLEAK=1; FOUND=1
  echo "${C_RED}  STALE${C_NC}  $file"
done < <(find "$ROOT" -type d \( -name bin -o -name publish -o -name Debug -o -name Release \) -prune -o -type f -false -print 2>/dev/null
         find "$ROOT" -path '*/bin/*' -o -path '*/publish/*' 2>/dev/null \
           | grep -E '/(\.env|sudo_password\.txt|login_password\.txt)$' || true)
[[ $BUILDLEAK -eq 0 ]] && say "${C_GRN}  none${C_NC}"

head2 "Canonical file"
if [[ -f "$CANONICAL" ]]; then
  MODE="$(stat -c '%a' "$CANONICAL" 2>/dev/null || echo '?')"
  COUNT="$(grep -cvE '^\s*(#|$)' "$CANONICAL" 2>/dev/null || echo 0)"
  if [[ "$MODE" == "600" ]]; then
    say "${C_GRN}  ok${C_NC}     $CANONICAL  (mode $MODE, $COUNT entries)"
  else
    echo "${C_YEL}  MODE${C_NC}   $CANONICAL is mode $MODE, want 600 — run: chmod 600 $CANONICAL"
    FOUND=1
  fi
else
  echo "${C_YEL}  MISSING${C_NC} $CANONICAL does not exist yet"
fi

head2 "Is .env excluded from sync and git?"
for ignore in "$ROOT/.gitignore" "$ROOT/30-source/.stignore" "$ROOT/.stignore"; do
  if [[ -f "$ignore" ]]; then
    if grep -qsE '(^|/)\.env' "$ignore"; then
      say "${C_GRN}  ok${C_NC}     $ignore excludes .env"
    else
      echo "${C_YEL}  GAP${C_NC}    $ignore does NOT exclude .env"
      FOUND=1
    fi
  fi
done

say ""
if [[ $FOUND -eq 1 ]]; then
  echo "${C_RED}FINDINGS — review the lines above.${C_NC}"
  say ""
  say "  For each LEAK: revoke that key at the provider, then put the new one"
  say "  ONLY in $CANONICAL and delete it from the file listed."
  say ""
  exit 1
fi
say "${C_GRN}Clean.${C_NC}"
say ""
exit 0
