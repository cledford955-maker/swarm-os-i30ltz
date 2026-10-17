#!/usr/bin/env bash
# Discard the stale copies and leftover worktrees of the two phone apps, AFTER proving nothing unique is in them.
# User decision 2026-10-10: the two phone apps live in ONE place each --
#   C Lucille Assistant  /mnt/lucillebuild/src/LucilleAssistant
#   D Boltz Recovery     /mnt/boltzbuild/src/I30LTZ-Recovery-companion
# and every other copy / worktree is thrown away once those two hold all of its work.
#
#   70-scripts/cleanup_phone_app_copies.sh            check everything, show what would go (changes nothing)
#   70-scripts/cleanup_phone_app_copies.sh --apply    check, then delete
#   --skip-worktree-check   skip the (slow, ~1 min) byte check of the 3 leftover worktrees against their branches
#
# What is checked first (any failure = nothing is deleted):
#   * C and D exist and are the real apps; D's signing key (debug.keystore) is identical to the old copy's
#   * the old Recovery-companion APKs were copied into D (dist/older-builds) and their checksums verify
#   * the 3 leftover worktrees still match the committed branches I30LTZ/* in /mnt/Lucy/.git (their work stays in git;
#     only the checkouts go). The Android Studio installer tarball inside two of them is ignored: it is not work.
# What it never touches: C, D, the Lucy git branches, /mnt/Lucy/lucille-companion (the older com.swarm.lucille app),
# ~/StudioProjects/i30ltz-lucille-assistant, 99-archive/companion-phone-backup-*, B's 99-archive/sda7-restore.
set -euo pipefail
export PATH=/usr/sbin:/sbin:$PATH

APPLY=0 DEEP=1
for a in "$@"; do case $a in
  --apply) APPLY=1 ;; --skip-worktree-check) DEEP=0 ;;
  -h|--help) sed -n '2,19p' "$0"; exit 0 ;;
  *) echo "unknown option: $a" >&2; exit 2 ;; esac; done

R=${CLEANUP_PREFIX:-}                          # test hook: every absolute path below is prefixed with this
HOME_DIR=${CLEANUP_HOME:-/home/i30ltz}
STRICT_TIPS=${CLEANUP_STRICT_TIPS:-1}          # test hook: 0 = do not require the exact branch tips below
LUCY=$R/mnt/Lucy SWB=$R/mnt/swarmbuild
C=$R/mnt/lucillebuild/src/LucilleAssistant
D=$R/mnt/boltzbuild/src/I30LTZ-Recovery-companion
DOLD=$R/mnt/boltzbuild/dist/older-builds
LEGACY="99-archive/companion-legacy-2026-09-25"
WT=$SWB/30-source/LucilleAssistant/.claude/worktrees
declare -A TIP=( [affectionate-sinoussi-53c2da]=cd4634e8576e8dcbf6624ff3078763dbf6784a56
                 [blissful-murdock-fa9e74]=fe7703ca8c4f5296b8e2e08f84d3811cbe19f437
                 [hungry-diffie-558618]=df3f38214458010c4f8b98bd721d5c608207e8e6 )

TARGETS=(
  "$SWB/30-source/LucilleAssistant|stale Lucille Assistant copy + the 3 leftover Claude worktrees (+ two Android Studio installers)"
  "$LUCY/30-source/LucilleAssistant|frozen Lucille Assistant copy (its history stays in git; live source is C)"
  "$HOME_DIR/Desktop/Lucille-Assistant.zip|zip snapshot of the old copy and the same 3 worktrees"
  "$HOME_DIR/.codex/worktrees/f25b|orphaned Codex worktree (broken git link; every file is in Lucy's git history)"
  "$LUCY/$LEGACY|old Recovery-companion source + APKs (source is in D, APKs copied to D/dist/older-builds)"
  "$SWB/$LEGACY|identical second copy of the above"
)

say() { printf '%s\n' "$*"; }
FAILS=0
bad() { say "  FAIL: $*"; FAILS=$((FAILS+1)); }
ok()  { say "  ok:   $*"; }

say "== checks"
# --- C and D are the real apps
[[ -d $C/.git && -f $C/go.mod && -f $C/app/build.gradle.kts ]] && ok "C Lucille Assistant present (HEAD $(git -C "$C" rev-parse --short HEAD 2>/dev/null || echo ?))" || bad "C is missing or incomplete: $C"
if [[ -d $D/.git && -f $D/app/build.gradle.kts ]] && grep -q 'com.aistudio.sysopt.app' "$D/app/build.gradle.kts"; then ok "D Boltz Recovery present (HEAD $(git -C "$D" rev-parse --short HEAD 2>/dev/null || echo ?))"; else bad "D is missing or is not the Recovery companion: $D"; fi

# --- D holds the signing key of the old copy
old_ks="$LUCY/$LEGACY/android_companion(seperate-related-project)/swarm_os-companion/debug.keystore"
if [[ -f $old_ks ]]; then
  if [[ -f $D/debug.keystore ]] && [[ $(sha256sum < "$old_ks") == $(sha256sum < "$D/debug.keystore") ]]; then ok "D's debug.keystore is identical to the old copy's"; else bad "D's debug.keystore differs from (or is missing next to) the old copy's: keep the old copy"; fi
fi

# --- the old APKs were copied into D and verify
if [[ -f $DOLD/SHA256SUMS ]] && ( cd "$DOLD" && sha256sum --quiet -c SHA256SUMS ); then ok "old Recovery-companion builds are in D/dist/older-builds and their checksums verify"
else bad "D/dist/older-builds is missing or does not verify (the old APKs would be lost)"; fi
legacy_app="$LUCY/$LEGACY/android_companion(seperate-related-project)"
if [[ -d $legacy_app && -f $DOLD/SHA256SUMS ]]; then
  while read -r sum name; do name=${name#\*}
    [[ -f $legacy_app/$name ]] || continue
    [[ $(sha256sum < "$legacy_app/$name" | cut -d' ' -f1) == "$sum" ]] || bad "$name in the old copy differs from the one in D"
  done < "$DOLD/SHA256SUMS"
  for f in "$legacy_app"/*.apk "$legacy_app"/*.zip; do [[ -e $f ]] || continue
    grep -q -F "$(basename "$f")" "$DOLD/SHA256SUMS" || bad "$(basename "$f") exists only in the old copy and is not in D/dist/older-builds"; done
fi

# --- the 3 leftover worktrees are committed on branches that stay in /mnt/Lucy/.git
for name in "${!TIP[@]}"; do
  br="I30LTZ/$name"; want=${TIP[$name]}
  have=$(git --git-dir="$LUCY/.git" rev-parse -q --verify "refs/heads/$br" 2>/dev/null || true)
  if [[ -z $have ]]; then bad "branch $br is missing from $LUCY/.git (the worktree's work would not be in git)"
  elif (( STRICT_TIPS )) && [[ $have != "$want" ]]; then bad "branch $br moved: $have (expected $want) - re-verify before deleting"
  else ok "branch $br is in Lucy's git (${have:0:7})"; fi
done
if (( DEEP )); then
  for name in "${!TIP[@]}"; do
    w=$WT/$name; [[ -d $w ]] || { say "  (worktree $name already gone)"; continue; }
    idx=$(mktemp -u); extra=$(
      export GIT_DIR=$LUCY/.git GIT_INDEX_FILE=$idx GIT_WORK_TREE=$w
      git read-tree "I30LTZ/$name" >/dev/null 2>&1 || { echo "UNREADABLE-BRANCH"; exit 0; }
      git update-index -q --refresh >/dev/null 2>&1 || true
      { git diff-files --name-only; git ls-files -o --exclude-standard; } | grep -v -x 'android-studio-quail4-patch1-linux.tar.gz' || true )
    rm -f "$idx"
    if [[ -z $extra ]]; then ok "worktree $name is byte-identical to its branch"; else bad "worktree $name differs from its branch: $(head -3 <<<"$extra" | tr '\n' ' ')..."; fi
  done
else say "  (worktree byte check skipped)"; fi

say; say "== would be deleted"
total=0
for t in "${TARGETS[@]}"; do p=${t%%|*}; why=${t#*|}
  if [[ -e $p || -L $p ]]; then sz=$(du -sk -- "$p" 2>/dev/null | cut -f1); total=$((total+sz)); printf '  %8s  %s\n            %s\n' "$(numfmt --to=iec --from-unit=1024 "$sz")" "$p" "$why"
  else printf '  %8s  %s  (already gone)\n' - "$p"; fi
done
say "  total about $(numfmt --to=iec --from-unit=1024 "$total")"

if (( FAILS )); then say; say "ABORT: $FAILS check(s) failed. Nothing was deleted."; exit 1; fi
if (( ! APPLY )); then say; say "Dry run: nothing was changed. Run again with --apply to delete the above."; exit 0; fi

say; say "== deleting"
for t in "${TARGETS[@]}"; do p=${t%%|*}
  [[ -e $p || -L $p ]] || continue
  [[ -L $p ]] && { say "  skip (is a symlink): $p"; continue; }
  mountpoint -q -- "$p" 2>/dev/null && { say "  skip (is a mount point): $p"; continue; }
  [[ $(realpath -- "$p") == "$p" ]] || { say "  skip (path resolves elsewhere: $(realpath -- "$p")): $p"; continue; }
  rm -rf --one-file-system -- "$p" && say "  deleted $p"
done
if [[ -d $SWB/.git ]]; then git -C "$SWB" worktree prune && say "  pruned stale worktree records in $SWB/.git"; fi
say; say "Done. C, D and the Lucy git branches (I30LTZ/*) were not touched."
