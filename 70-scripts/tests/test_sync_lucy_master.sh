#!/usr/bin/env bash
# Tests sync_lucy_master.sh on fake folders (LUCY_ROOT, LUCY_MASTER_MOUNT): nothing real is touched.
# Run: bash 70-scripts/tests/test_sync_lucy_master.sh
set -euo pipefail
HERE=$(cd "$(dirname "$0")/.." && pwd); S="$HERE/sync_lucy_master.sh"
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
fail() { echo "FAIL: $*"; exit 1; }; ok() { echo "ok   $*"; }
export SWARM_SYNC_IDENTITY_A=uuid-lucy SWARM_SYNC_IDENTITY_B=uuid-master SWARM_SYNC_FREE_MARGIN=0
L=$T/Lucy; M=$T/master
sy() { LUCY_ROOT=$L LUCY_MASTER_MOUNT=$M LUCY_MASTER_NO_MOUNT_CHECK=1 bash "$S" "$@" 2>&1; }
fresh() { rm -rf "$L" "$M"; mkdir -p "$L/70-scripts" "$M/Lucy-mirror" "$M/old-world/stuff"; echo big > "$M/old-world/stuff/huge.bin"; }

# 1. --list-top is read-only and lists folders
fresh; out=$(sy --list-top); [[ $out == *"Lucy-mirror"* && $out == *"old-world"* ]] || fail "list-top: $out"
[[ ! -e $L/.swarm-sync ]] || fail "list-top must not create state"; ok "--list-top lists lucy-master's folders and changes nothing"

# 2. --subdir is mandatory, must exist, must be plain
fresh; out=$(sy 2>&1) && fail "no --subdir should fail"; [[ $out == *"--subdir NAME is required"* ]] || fail "$out"
out=$(sy --subdir nope 2>&1) && fail "missing subdir should fail"; [[ $out == *"does not exist"* ]] || fail "$out"
out=$(sy --subdir ../x 2>&1) && fail "dotdot should fail"; out=$(sy --subdir /abs 2>&1) && fail "absolute should fail"
ok "--subdir is required, must exist and must be a plain folder name (never the whole volume)"

# 3. locked / not mounted: says how to unlock, touches nothing
fresh; out=$(LUCY_ROOT=$L LUCY_MASTER_FS_UUID=00000000-0000-0000-0000-000000000000 bash "$S" --subdir x 2>&1) && fail "should refuse when lucy-master is not mounted"
[[ $out == *"locked"* && $out == *"cryptsetup open /dev/disk/by-uuid/a24202ce-4d76-4eb7-8923-8e8ddbacdaa7"* ]] || fail "$out"
ok "locked/unmounted lucy-master: refuses and prints the exact unlock command"

# 4. first run (dry) shows the plan and copies nothing; apply copies both ways and NEVER deletes on a first run
fresh; echo "lucy only" > "$L/a.txt"; echo "master only" > "$M/Lucy-mirror/b.txt"; echo "both-old" > "$L/c.txt"; echo "both-old" > "$M/Lucy-mirror/c.txt"
out=$(sy --subdir Lucy-mirror); [[ $out == *"first run cannot delete anything"* && $out == *"DRY RUN"* && $out == *"Lucy project"* ]] || fail "dry run: $out"
[[ ! -e $M/Lucy-mirror/a.txt && ! -e $L/b.txt ]] || fail "dry run copied something"
sy --subdir Lucy-mirror --apply >/dev/null
[[ -f $M/Lucy-mirror/a.txt && -f $L/b.txt ]] || fail "first apply must copy new files in BOTH directions"
[[ -f $L/c.txt && -f $M/Lucy-mirror/c.txt ]] || fail "first run must not delete"; ok "first run: new data copied both ways, nothing deleted"

# 5. later runs: a real deletion propagates, new data on the other side is kept
echo "new on master" > "$M/Lucy-mirror/d.txt"; rm "$L/c.txt"
sy --subdir Lucy-mirror --apply >/dev/null
[[ ! -e $M/Lucy-mirror/c.txt ]] || fail "c.txt was deleted on Lucy, so it must go from lucy-master too"
[[ -f $L/d.txt && $(cat "$L/d.txt") == "new on master" ]] || fail "d.txt is NEW on lucy-master and must reach Lucy, not be deleted"
find "$M/Lucy-mirror/.sync-trash" -name c.txt 2>/dev/null | grep -q . || fail "the deleted copy must be kept in a trash"
ok "real deletions propagate (to trash); new files on the other side are copied, not deleted"

# 6. the history and trash are never synced onto the other side; the rest of lucy-master is untouched
[[ ! -e $M/Lucy-mirror/.swarm-sync && -d $L/.swarm-sync/master ]] || fail "state dir must live on Lucy only"
[[ -f $M/old-world/stuff/huge.bin ]] && [[ ! -e $L/old-world ]] || fail "other folders on lucy-master must not be touched or pulled in"
ok "history stays on Lucy; the rest of lucy-master is untouched and not pulled in"

# 7. a copy that does not fit is refused
fresh; head -c 5000 /dev/zero > "$M/Lucy-mirror/big.bin"; out=$(SWARM_SYNC_FREE_A=1000 sy --subdir Lucy-mirror --apply 2>&1) && fail "should refuse"
[[ $out == *"REFUSED"* && ! -e $L/big.bin ]] || fail "$out"; ok "a copy that does not fit is refused before anything is copied"
echo "ALL OK"
