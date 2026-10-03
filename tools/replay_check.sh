#!/bin/bash
# Determinism check: replay the same MP replay several times (and at several tick batch sizes) headlessly and
# compare the final world/map Rand states MP prints. Identical = deterministic on this machine.
# Usage: tools/replay_check.sh <replayName> <ticks> [profile=test] [runs=3] [batches="1 60 600"]
#   <replayName> = file name (no .zip) in ~/rw-mp-<profile>/MpReplays (recorded via "Dev: save replay").
# Output: out/replay/<replayName>/<label> per run, plus a verdict. Exit 1 on mismatch, 2 on a failed/hung run.
# What it exercises: MP loads the replay's LAST section (snapshot at the last join point), replays that section's
# recorded commands, then free-runs <ticks> more. With the default host setting (auto join-points = Join|Desync, NOT
# Autosave) a solo+Arbiter session has one section, so the whole recorded session is replayed.
# Env: RUN_TIMEOUT (seconds per run, default 1200).
set -uo pipefail
NAME="${1:?replay name}"; TICKS="${2:?ticks}"; PROFILE="${3:-test}"; RUNS="${4:-3}"; BATCHES="${5:-1 60 600}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/out/replay/$NAME"; mkdir -p "$OUT"
REPLAY="$HOME/rw-mp-$PROFILE/MpReplays/$NAME.zip"
[[ -f "$REPLAY" ]] || { echo "!! no replay at $REPLAY"; exit 2; }
pgrep -x RimWorldLinux >/dev/null && { echo "!! RimWorld is already running; quit it first (same profile/Steam instance)"; exit 2; }
pgrep -x steam >/dev/null || { echo "!! Steam isn't running; start it first (steam -silent)"; exit 2; }
labels=()
for b in $BATCHES; do
  for r in $(seq 1 "$RUNS"); do
    label="b${b}_r${r}"; rm -f "$OUT/$label"
    echo ">> $label"
    start=$SECONDS
    timeout "${RUN_TIMEOUT:-1200}" "$ROOT/tools/rw.sh" "$PROFILE" "-replay=$label:$NAME:$TICKS:$b" "-replaydata=$OUT" >/dev/null 2>&1
    rc=$?
    [[ $rc == 124 ]] && { echo "!! $label timed out after ${RUN_TIMEOUT:-1200}s (see ~/rw-mp-$PROFILE/Player.log)"; pkill -x RimWorldLinux; exit 2; }
    [[ -s "$OUT/$label" ]] || { echo "!! $label produced no output (exit $rc; see ~/rw-mp-$PROFILE/Player.log)"; exit 2; }
    echo "   done in $((SECONDS - start))s"
    labels+=("$label")
  done
done
ref="${labels[0]}"; bad=0
for l in "${labels[@]:1}"; do
  if ! diff -q <(grep -v '^TPS' "$OUT/$ref") <(grep -v '^TPS' "$OUT/$l") >/dev/null; then
    echo "MISMATCH $ref vs $l"; diff <(grep -v '^TPS' "$OUT/$ref") <(grep -v '^TPS' "$OUT/$l") | head -20; bad=1
  fi
done
grep -h '^TPS' "$OUT"/b* | sed 's/^/  /'
[[ $bad == 0 ]] && echo "DETERMINISTIC: ${#labels[@]} runs identical" || { echo "NOT DETERMINISTIC"; exit 1; }
