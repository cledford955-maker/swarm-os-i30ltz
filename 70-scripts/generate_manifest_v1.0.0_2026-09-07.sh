#!/usr/bin/env bash
# generate_manifest 1.0.0 (2026-09-07) - dated inventory of the LUCILLE drive
set -uo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
R="$(dirname "$SCRIPT_DIR")"
DATE="$(date +%Y-%m-%d)"
VER="$(tr -d '[:space:]' < "$R/VERSION" 2>/dev/null || echo unknown)"
OUT="$R/90-docs/MANIFEST_${DATE}.md"

{
  echo "# LUCILLE drive manifest"
  echo "\`generated $(date -Iseconds) · SWARM OS v${VER} · layout v1.0.0\`"
  echo
  echo "## Capacity"
  echo '```'
  df -h "$R" | tail -1 | awk '{printf "size %s   used %s   free %s   (%s used)\n",$2,$3,$4,$5}'
  echo '```'
  echo
  echo "## Top level"
  echo
  echo "| Folder | Size | Files | Status |"
  echo "|---|---|---|---|"
  for d in "$R"/[0-9]*/; do
    n="$(basename "$d")"
    sz="$(du -sh "$d" 2>/dev/null | cut -f1)"
    fc="$(find "$d" -type f 2>/dev/null | wc -l)"
    st="ok"
    [ "$fc" -eq 0 ] && st="**EMPTY — awaiting restore**"
    printf "| \`%s\` | %s | %s | %s |\n" "$n" "$sz" "$fc" "$st"
  done
  echo
  echo "## Versioned artifacts (newest first)"
  echo
  echo '```'
  find "$R" -type f \( -name '*_v*_20*' -o -name '*.iso' \) \
       -printf '%TY-%Tm-%Td  %-58f  %10s bytes\n' 2>/dev/null | sort -r
  echo '```'
  echo
  echo "## Releases"
  echo
  python "$R/70-scripts/swarm_iso_manager.py" list || echo '_Ventoy not mounted; no local ISO fallback._'
  echo
  echo "## 00-CURRENT pointers"
  echo
  echo '```'
  ls -l "$R/00-CURRENT" | grep '\->' | awk '{print $9, $10, $11}'
  echo '```'
} > "$OUT"

echo "wrote $OUT"
exit 0
