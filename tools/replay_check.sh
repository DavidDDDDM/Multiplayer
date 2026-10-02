#!/bin/bash
# Determinism check: replay the same MP replay several times (and at several tick batch sizes) headlessly and
# compare the final world/map Rand states MP prints. Identical = deterministic on this machine.
# Usage: tools/replay_check.sh <replayName> <ticks> [profile=test] [runs=3] [batches="1 60 600"]
#   <replayName> = file name (no .zip) in ~/rw-mp-<profile>/MpReplays (recorded via "Dev: save replay").
# Output: out/replay/<replayName>/<label> per run, plus a verdict. Exit 1 on mismatch.
set -uo pipefail
NAME="${1:?replay name}"; TICKS="${2:?ticks}"; PROFILE="${3:-test}"; RUNS="${4:-3}"; BATCHES="${5:-1 60 600}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/out/replay/$NAME"; mkdir -p "$OUT"
labels=()
for b in $BATCHES; do
  for r in $(seq 1 "$RUNS"); do
    label="b${b}_r${r}"; rm -f "$OUT/$label"
    echo ">> $label"
    "$ROOT/tools/rw.sh" "$PROFILE" "-replay=$label:$NAME:$TICKS:$b" "-replaydata=$OUT" >/dev/null 2>&1
    [[ -s "$OUT/$label" ]] || { echo "!! $label produced no output (see ~/rw-mp-$PROFILE/Player.log)"; exit 2; }
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
