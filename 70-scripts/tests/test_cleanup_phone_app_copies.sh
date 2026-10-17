#!/usr/bin/env bash
# Tests cleanup_phone_app_copies.sh on a FAKE tree (CLEANUP_PREFIX / CLEANUP_HOME): nothing real is touched.
# Run: bash 70-scripts/tests/test_cleanup_phone_app_copies.sh
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd); S="$HERE/cleanup_phone_app_copies.sh"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
fail() { echo "FAIL: $*"; exit 1; }; ok() { echo "ok   $*"; }
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
M=$T/mnt; H=$T/home
LEG="99-archive/companion-legacy-2026-09-25"; OLD="$M/Lucy/$LEG/android_companion(seperate-related-project)"
NAMES="affectionate-sinoussi-53c2da blissful-murdock-fa9e74 hungry-diffie-558618"

build() {   # a complete, healthy fake world
  rm -rf "$M" "$H"
  mkdir -p "$M/Lucy" "$M/swarmbuild" "$H/Desktop" "$H/.codex/worktrees/f25b" "$M/lucillebuild/src" "$M/boltzbuild/src" "$M/boltzbuild/dist/older-builds"
  # Lucy repo with 3 branches; each worktree dir is an exact checkout of its branch
  git -C "$M/Lucy" init -q -b main; echo base > "$M/Lucy/README.md"; mkdir -p "$M/Lucy/lucille-companion"; echo keep > "$M/Lucy/lucille-companion/x.kt"
  git -C "$M/Lucy" add -A; git -C "$M/Lucy" commit -q -m base
  for n in $NAMES; do
    git -C "$M/Lucy" checkout -q -b "I30LTZ/$n" main; echo "work of $n" > "$M/Lucy/work-$n.txt"; git -C "$M/Lucy" add -A; git -C "$M/Lucy" commit -q -m "$n"
    git -C "$M/Lucy" checkout -q main; git -C "$M/Lucy" archive "I30LTZ/$n" | { mkdir -p "$M/swarmbuild/30-source/LucilleAssistant/.claude/worktrees/$n"; tar -x -C "$M/swarmbuild/30-source/LucilleAssistant/.claude/worktrees/$n"; }
    echo "installer" > "$M/swarmbuild/30-source/LucilleAssistant/.claude/worktrees/$n/android-studio-quail4-patch1-linux.tar.gz"
  done
  git -C "$M/swarmbuild" init -q
  mkdir -p "$M/Lucy/30-source/LucilleAssistant"; echo old > "$M/Lucy/30-source/LucilleAssistant/main.go"
  echo zip > "$H/Desktop/Lucille-Assistant.zip"; echo cx > "$H/.codex/worktrees/f25b/file"
  # C and D
  C=$M/lucillebuild/src/LucilleAssistant; mkdir -p "$C/app"; git -C "$C" init -q; echo "module x" > "$C/go.mod"; echo "// c" > "$C/app/build.gradle.kts"; git -C "$C" add -A; git -C "$C" commit -q -m c
  D=$M/boltzbuild/src/I30LTZ-Recovery-companion; mkdir -p "$D/app"; git -C "$D" init -q; echo 'applicationId = "com.aistudio.sysopt.app"' > "$D/app/build.gradle.kts"; echo KEY > "$D/debug.keystore"; git -C "$D" add -A; git -C "$D" commit -q -m d
  # the archive copy of the old Recovery companion + its builds, copied into D
  mkdir -p "$OLD/swarm_os-companion" "$M/swarmbuild/$LEG"; echo KEY > "$OLD/swarm_os-companion/debug.keystore"; echo apk1 > "$OLD/SWARM_OS_Companion.apk"; echo z > "$OLD/old.zip"
  cp -a "$M/Lucy/$LEG" "$M/swarmbuild/99-archive/" 2>/dev/null || { mkdir -p "$M/swarmbuild/99-archive"; cp -a "$M/Lucy/$LEG" "$M/swarmbuild/99-archive/"; }
  cp "$OLD/SWARM_OS_Companion.apk" "$OLD/old.zip" "$M/boltzbuild/dist/older-builds/"; ( cd "$M/boltzbuild/dist/older-builds" && sha256sum *.apk *.zip > SHA256SUMS )
  # things that must survive
  mkdir -p "$M/Lucy/99-archive/companion-phone-backup-2026-09-25" "$H/StudioProjects/i30ltz-lucille-assistant"; echo db > "$M/Lucy/99-archive/companion-phone-backup-2026-09-25/dr_boltz_db"; echo studio > "$H/StudioProjects/i30ltz-lucille-assistant/f"
}
run() { CLEANUP_PREFIX="$T" CLEANUP_HOME="$H" CLEANUP_STRICT_TIPS=0 bash "$S" "$@" 2>&1; }
survivors() { [[ -d $M/lucillebuild/src/LucilleAssistant/.git && -d $M/boltzbuild/src/I30LTZ-Recovery-companion/.git && -f $M/Lucy/lucille-companion/x.kt && -f $M/Lucy/99-archive/companion-phone-backup-2026-09-25/dr_boltz_db && -f $H/StudioProjects/i30ltz-lucille-assistant/f && -f $M/boltzbuild/dist/older-builds/SHA256SUMS ]]; }
alive() { [[ -e $M/swarmbuild/30-source/LucilleAssistant && -e $M/Lucy/30-source/LucilleAssistant && -e $H/Desktop/Lucille-Assistant.zip && -e $H/.codex/worktrees/f25b && -e $M/Lucy/$LEG && -e $M/swarmbuild/$LEG ]]; }

# 1. dry run: all checks pass, lists the targets, deletes nothing
build; out=$(run); [[ $out == *"Dry run: nothing was changed"* && $out == *"byte-identical"* ]] || fail "dry run output: $out"
alive && survivors || fail "dry run deleted something"; ok "dry run: checks pass, lists the targets, deletes nothing"

# 2. apply: removes exactly the six targets and nothing else
out=$(run --apply) || fail "apply failed: $out"
[[ ! -e $M/swarmbuild/30-source/LucilleAssistant && ! -e $M/Lucy/30-source/LucilleAssistant && ! -e $H/Desktop/Lucille-Assistant.zip && ! -e $H/.codex/worktrees/f25b && ! -e $M/Lucy/$LEG && ! -e $M/swarmbuild/$LEG ]] || fail "a target survived"
survivors || fail "apply deleted something it must keep"
git -C "$M/Lucy" rev-parse -q --verify refs/heads/I30LTZ/blissful-murdock-fa9e74 >/dev/null || fail "the Lucy branches must survive"
ok "apply: the six targets are gone; C, D, Lucy branches, lucille-companion, phone backup, Studio project untouched"
out=$(run --apply) || fail "second apply failed: $out"; ok "idempotent: a second run with everything gone is harmless"

# 3. a worktree edited after the fact => abort, nothing deleted
build; echo "uncommitted edit" >> "$M/swarmbuild/30-source/LucilleAssistant/.claude/worktrees/blissful-murdock-fa9e74/README.md"
out=$(run --apply) && fail "must abort on a modified worktree"; [[ $out == *"differs from its branch"* && $out == *"Nothing was deleted"* ]] || fail "message: $out"
alive && survivors || fail "deleted despite a modified worktree"; ok "a worktree with an edit not in git => aborts, deletes nothing"

# 4. a NEW untracked file in a worktree => abort
build; echo "new work" > "$M/swarmbuild/30-source/LucilleAssistant/.claude/worktrees/hungry-diffie-558618/notes.txt"
out=$(run --apply) && fail "must abort on an untracked file"; alive || fail "deleted despite an untracked file"; ok "an untracked file in a worktree => aborts"

# 5. a missing branch => abort
build; git -C "$M/Lucy" branch -q -D I30LTZ/affectionate-sinoussi-53c2da
out=$(run --apply) && fail "must abort when a branch is missing"; [[ $out == *"is missing"* ]] || fail "$out"; alive || fail "deleted"; ok "a missing branch => aborts"

# 6. the old APKs not copied to D => abort (they would be lost)
build; rm "$M/boltzbuild/dist/older-builds/SWARM_OS_Companion.apk"
out=$(run --apply) && fail "must abort when an APK is not in D"; alive || fail "deleted"; ok "APKs missing from D => aborts"
build; echo extra > "$OLD/ONLY_HERE.apk"
out=$(run --apply) && fail "must abort for an APK that exists only in the old copy"; [[ $out == *"ONLY_HERE.apk"* ]] || fail "$out"; alive || fail "deleted"; ok "an APK that exists only in the old copy => aborts"

# 7. different signing key => abort
build; echo OTHER > "$M/boltzbuild/src/I30LTZ-Recovery-companion/debug.keystore"
out=$(run --apply) && fail "must abort on a different keystore"; [[ $out == *"debug.keystore differs"* ]] || fail "$out"; alive || fail "deleted"; ok "D with a different debug.keystore => aborts"

# 8. C or D missing => abort
build; rm -rf "$M/lucillebuild/src/LucilleAssistant"; out=$(run --apply) && fail "must abort without C"; alive || fail "deleted"; ok "C missing => aborts"
build; rm -rf "$M/boltzbuild/src/I30LTZ-Recovery-companion"; out=$(run --apply) && fail "must abort without D"; alive || fail "deleted"; ok "D missing => aborts"

# 9. a symlinked target is skipped, never followed
build; rm -rf "$H/.codex/worktrees/f25b"; mkdir -p "$T/elsewhere"; echo precious > "$T/elsewhere/f"; ln -s "$T/elsewhere" "$H/.codex/worktrees/f25b"
out=$(run --apply) || fail "$out"; [[ -f $T/elsewhere/f ]] || fail "followed a symlink and deleted its target"; ok "a symlinked target is skipped, its target survives"
echo "ALL OK"
