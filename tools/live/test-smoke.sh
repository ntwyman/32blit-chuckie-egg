#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2020-2026 ntwyman
set -uo pipefail

LIVE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRIVE="${DRIVE:-$LIVE/drive.sh}"
GOLDEN="${LIVE_GOLDEN:-$LIVE/golden/level1-start.png}"
RUNS="${RUNS:-10}"
SAME_AS_GOLDEN_AE="${SAME_AS_GOLDEN_AE:-8}"
TMP="$(mktemp -d)"
LANE=23
failures=0

cleanup() {
  LIVE_LANE=$LANE "$DRIVE" stop >/dev/null 2>&1
  rm -rf "/tmp/chuckie-live-$((99 + LANE))" "$TMP"
}
trap cleanup EXIT

check() {
  local name="$1"
  shift
  if "$@"; then
    echo "ok   $name"
  else
    echo "FAIL $name"
    failures=$((failures + 1))
  fi
}

ae() {
  compare -metric AE "$1" "$2" null: 2>&1 || true
}

run_smoke() {
  LIVE_LANE=$LANE LIVE_OUT_DIR="$TMP/out" LIVE_SMOKE_ATTEMPTS=3 "$DRIVE" smoke >"$TMP/smoke.out" 2>&1
  echo $? >"$TMP/smoke.rc"
}

t_selection_is_the_same_every_run() {
  local i delays="" frames="" seen
  for i in $(seq 1 "$RUNS"); do
    run_smoke
    seen="$(grep -o 'selected frame [0-9]*, [0-9]* frames' "$TMP/smoke.out" | head -1)"
    [ -n "$seen" ] || {
      echo "  run $i: no frame selected"
      cat "$TMP/smoke.out"
      return 1
    }
    frames="$frames ${seen#selected frame }"
    delays="$delays $(sed 's/.*, \([0-9]*\) frames/\1/' <<<"$seen")"
    cp "$TMP/out/smoke.png" "$TMP/pick-$i.png"
    echo "  run $i: $seen, $(ae "$TMP/pick-$i.png" "$GOLDEN") px from the golden image"
  done
  local spread
  spread="$(printf '%s\n' $delays | sort -n | awk 'NR == 1 { lo = $1 } { hi = $1 } END { print hi - lo }')"
  echo "  frames after the ready screen first showed:$delays (spread $spread)"
  [ "$spread" -le 6 ]
}

t_every_selection_shows_level_1_start() {
  local i
  for i in $(seq 1 "$RUNS"); do
    [ "$(ae "$TMP/pick-$i.png" "$GOLDEN")" -le "$SAME_AS_GOLDEN_AE" ] || return 1
  done
}

make_wrong_goldens() {
  (
    set +e
    export LIVE_LANE=$LANE
    source "$DRIVE"
    set +e
    cmd_start >/dev/null 2>&1
    record_start "$TMP/wrong.mkv" >/dev/null 2>&1
    stop_procs
    frame_hashes "$TMP/wrong.mkv" | awk '$0 != prev { runs++; start[runs] = NR - 1 } { prev = $0; last = NR - 1 }
      END { print start[1] + 5, start[2] + 5, (runs >= 4 ? start[4] : last) }' >"$TMP/wrong.idx"
    read -r how ready later <"$TMP/wrong.idx"
    frame_png "$TMP/wrong.mkv" "$how" "$TMP/wrong-howmany.png"
    frame_png "$TMP/wrong.mkv" "$ready" "$TMP/wrong-ready.png"
    frame_png "$TMP/wrong.mkv" "$later" "$TMP/wrong-later.png"
    echo "  wrong golden frames: how-many $how, ready $ready, later level-1 $later"
  )
}

t_a_wrong_golden_fails() {
  local name="$1" out
  out="$(LIVE_LANE=$LANE LIVE_OUT_DIR="$TMP/out-$name" LIVE_GOLDEN="$TMP/wrong-$name.png" "$DRIVE" smoke 2>&1)"
  local rc=$?
  echo "  $name: rc=$rc, $(grep -o 'FAILED, [0-9]* pixels differ' <<<"$out")"
  [ "$rc" = 1 ] && [[ "$out" == *"pixels differ"* ]] && [[ "$out" != *retrying* ]]
}

check "frame selection is the same relative to the key press in $RUNS runs" t_selection_is_the_same_every_run
check "every selected frame shows level 1 at the start" t_every_selection_shows_level_1_start
make_wrong_goldens
for name in howmany ready later; do
  check "a golden from the $name frame fails" t_a_wrong_golden_fails "$name"
done

[ "$failures" = 0 ] || {
  echo "$failures check(s) failed"
  exit 1
}
echo "all checks passed"
