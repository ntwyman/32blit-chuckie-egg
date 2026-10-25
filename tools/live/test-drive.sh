#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2020-2026 ntwyman
set -uo pipefail

LIVE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRIVE="${DRIVE:-$LIVE/drive.sh}"
TMP="$(mktemp -d)"
LANE_BASE="${LIVE_TEST_LANE_BASE:-10}"
LANES="$(seq "$LANE_BASE" "$((LANE_BASE + 9))")"
failures=0

cleanup() {
  local lane
  for lane in $LANES; do
    LIVE_LANE=$lane "$DRIVE" stop >/dev/null 2>&1
    rm -rf "/tmp/chuckie-live-$((99 + lane))" "$LIVE/out/lane$lane"
  done
  pkill -f "$TMP/" 2>/dev/null
  rm -rf "$TMP"
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

lane_state() {
  echo "/tmp/chuckie-live-$((99 + $1))"
}

recorder_count() {
  pgrep -fc "ffmpeg.* -i :$((99 + $1)) " || true
}

t_glob_in_key_script() {
  local d="$TMP/glob"
  mkdir -p "$d"
  : >"$d/z"
  printf '* 100\n' >"$TMP/glob.keys"
  (cd "$d" && LIVE_LANE=$((LANE_BASE + 0)) "$DRIVE" keys "$TMP/glob.keys" >/dev/null 2>&1)
  [ $? = 2 ]
}

t_empty_script_is_a_noop() {
  printf '# nothing\n\n' >"$TMP/empty.keys"
  LIVE_LANE=$((LANE_BASE + 0)) "$DRIVE" keys "$TMP/empty.keys"
}

t_rejects_empty_combo_parts() {
  local script out
  for script in 'left++up 100' '+z 100' 'z+ 100'; do
    printf 'wait 1\n%s\n' "$script" >"$TMP/combo.keys"
    out="$(LIVE_LANE=$((LANE_BASE + 0)) "$DRIVE" keys "$TMP/combo.keys" 2>&1)"
    [ $? = 2 ] || return 1
    [[ "$out" == *"combo.keys:2:"* ]] || return 1
  done
}

t_readme_lists_every_accepted_key() {
  local key
  for key in u i o p; do
    grep -q "^| .*\`$key\`" "$LIVE/README.md" || return 1
  done
}

t_stop_spares_a_foreign_pid() {
  local lane=$((LANE_BASE + 1)) state pid
  state="$(lane_state $lane)"
  mkdir -p "$state"
  sleep 300 &
  pid=$!
  echo "$pid" >"$state/game.pid"
  LIVE_LANE=$lane "$DRIVE" stop >/dev/null 2>&1
  kill -0 "$pid" 2>/dev/null
  local alive=$?
  kill "$pid" 2>/dev/null
  return $alive
}

t_start_ignores_a_foreign_pid() {
  local lane=$((LANE_BASE + 1)) state pid out
  state="$(lane_state $lane)"
  mkdir -p "$state"
  sleep 300 &
  pid=$!
  echo "$pid" >"$state/game.pid"
  out="$(LIVE_LANE=$lane LIVE_BIN=/bin/true "$DRIVE" start 2>&1)"
  kill "$pid" 2>/dev/null
  [[ "$out" != *"already running"* ]]
}

t_stop_kills_a_background_recorder() {
  local lane=$((LANE_BASE + 2))
  LIVE_LANE=$lane "$DRIVE" start >/dev/null 2>&1 || return 1
  LIVE_LANE=$lane "$DRIVE" record 30 "$TMP/rec.mp4" 2>/dev/null &
  sleep 1.5
  [ "$(recorder_count $lane)" -ge 1 ] || return 1
  LIVE_LANE=$lane "$DRIVE" stop >/dev/null 2>&1
  sleep 0.5
  [ "$(recorder_count $lane)" = 0 ]
}

kill_smoke_mid_recording() {
  local lane="$1" signal="$2" i smoke
  LIVE_LANE=$lane LIVE_OUT_DIR="$TMP/killed" "$DRIVE" smoke >/dev/null 2>&1 &
  smoke=$!
  for i in $(seq 1 100); do
    [ "$(recorder_count "$lane")" -ge 1 ] && break
    sleep 0.1
  done
  [ "$(recorder_count "$lane")" -ge 1 ] || return 1
  kill "-$signal" "$smoke"
  wait "$smoke" 2>/dev/null
  sleep 1
}

t_terminated_smoke_leaves_no_recorder() {
  local lane=$((LANE_BASE + 3))
  kill_smoke_mid_recording "$lane" TERM || return 1
  [ "$(recorder_count $lane)" = 0 ] && ! pgrep -f "Xvfb :$((99 + lane))" >/dev/null
}

t_stop_cleans_up_after_a_killed_smoke() {
  local lane=$((LANE_BASE + 3))
  kill_smoke_mid_recording "$lane" KILL || return 1
  LIVE_LANE=$lane "$DRIVE" stop >/dev/null 2>&1
  sleep 0.5
  [ "$(recorder_count $lane)" = 0 ] && ! pgrep -f "Xvfb :$((99 + lane))" >/dev/null
}

t_lanes_run_side_by_side() {
  local a=$((LANE_BASE + 4)) b=$((LANE_BASE + 5)) rc_a rc_b
  rm -rf "$LIVE/out/lane$a" "$LIVE/out/lane$b"
  LIVE_LANE=$a "$DRIVE" smoke >"$TMP/lane-a.log" 2>&1 &
  local pa=$!
  LIVE_LANE=$b "$DRIVE" smoke >"$TMP/lane-b.log" 2>&1 &
  local pb=$!
  wait "$pa"
  rc_a=$?
  wait "$pb"
  rc_b=$?
  sed 's/^/  lane a: /' "$TMP/lane-a.log"
  sed 's/^/  lane b: /' "$TMP/lane-b.log"
  [ -s "$LIVE/out/lane$a/smoke.png" ] && [ -s "$LIVE/out/lane$b/smoke.png" ] || return 1
  [ "$rc_a" = 0 ] && [ "$rc_b" = 0 ] && ! grep -q 'run failed' "$TMP/lane-a.log" "$TMP/lane-b.log"
}

t_stop_removes_logs_after_a_clean_run() {
  local lane=$((LANE_BASE + 6)) state
  state="$(lane_state $lane)"
  LIVE_LANE=$lane "$DRIVE" start >/dev/null 2>&1 || return 1
  LIVE_LANE=$lane "$DRIVE" stop >/dev/null 2>&1
  [ ! -e "$state/game.log" ] && [ ! -e "$state/xvfb.log" ]
}

t_failed_start_keeps_logs_and_says_where() {
  local lane=$((LANE_BASE + 6)) state out
  state="$(lane_state $lane)"
  printf '#!/bin/sh\necho boom\nexit 1\n' >"$TMP/crash.sh"
  chmod +x "$TMP/crash.sh"
  out="$(LIVE_LANE=$lane LIVE_BIN="$TMP/crash.sh" "$DRIVE" start 2>&1)"
  [ $? != 0 ] || return 1
  LIVE_LANE=$lane "$DRIVE" stop >/dev/null 2>&1
  [[ "$out" == *"$state"* ]] && grep -q boom "$state/game.log"
}

t_smoke_rejects_other_screen_sizes() {
  local out
  out="$(LIVE_LANE=$((LANE_BASE + 7)) LIVE_SCREEN=800x600x24 "$DRIVE" smoke 2>&1)"
  [ $? != 0 ] && [[ "$out" == *640x480* ]]
}

t_start_fails_without_a_window() {
  printf '#!/bin/bash\nexec sleep 60\n' >"$TMP/nowindow.sh"
  chmod +x "$TMP/nowindow.sh"
  LIVE_LANE=$((LANE_BASE + 7)) LIVE_BIN="$TMP/nowindow.sh" LIVE_WINDOW_WAIT=1 "$DRIVE" start >/dev/null 2>&1
  [ $? != 0 ]
}

t_stop_escalates_to_kill() {
  local lane=$((LANE_BASE + 8)) marker="$TMP/ignore-term.sh"
  printf '#!/bin/bash\ntrap "" TERM\nwhile :; do sleep 1; done\n' >"$marker"
  chmod +x "$marker"
  LIVE_LANE=$lane LIVE_BIN="$marker" LIVE_WINDOW_WAIT=1 "$DRIVE" start >/dev/null 2>&1
  LIVE_LANE=$lane "$DRIVE" stop >/dev/null 2>&1
  ! pgrep -f "$marker" >/dev/null
}

t_start_spares_a_held_display_lock() {
  local lane=$((LANE_BASE + 9)) holder
  sleep 300 &
  holder=$!
  printf '%10d\n' "$holder" >/tmp/.X$((99 + lane))-lock
  LIVE_LANE=$lane "$DRIVE" start >/dev/null 2>&1
  local rc=$?
  local kept=0
  [ -f /tmp/.X$((99 + lane))-lock ] && kept=1
  kill "$holder" 2>/dev/null
  rm -f /tmp/.X$((99 + lane))-lock
  [ "$rc" != 0 ] && [ "$kept" = 1 ]
}

t_start_waits_for_a_slow_xvfb() {
  local lane=$((LANE_BASE + 9)) real
  real="$(command -v Xvfb)"
  mkdir -p "$TMP/slowbin"
  printf '#!/bin/bash\nsleep 6\nexec %s "$@"\n' "$real" >"$TMP/slowbin/Xvfb"
  chmod +x "$TMP/slowbin/Xvfb"
  PATH="$TMP/slowbin:$PATH" LIVE_LANE=$lane "$DRIVE" start >/dev/null 2>&1
  local rc=$?
  LIVE_LANE=$lane "$DRIVE" stop >/dev/null 2>&1
  [ "$rc" = 0 ]
}

t_rejects_a_non_numeric_lane() {
  local out
  out="$(LIVE_LANE=abc "$DRIVE" stop 2>&1)"
  [ $? != 0 ] && [[ "$out" == *"LIVE_LANE must be"* ]]
}

t_failed_smoke_leaves_artifacts() {
  local lane=$((LANE_BASE + 0)) out dir
  dir="$LIVE/out/lane$lane"
  rm -rf "$dir"
  convert -size 640x480 xc:white "$TMP/white.png"
  out="$(LIVE_LANE=$lane LIVE_GOLDEN="$TMP/white.png" LIVE_SMOKE_ATTEMPTS=3 "$DRIVE" smoke 2>&1)"
  [ $? = 1 ] || return 1
  [ -s "$dir/smoke.png" ] && [ -s "$dir/game.log" ] || return 1
  [ "$(grep -c 'selected frame' <<<"$out")" = 1 ] && [[ "$out" != *retrying* ]]
}

t_smoke_ignores_a_script_in_the_current_directory() {
  local d="$TMP/hijack" out
  mkdir -p "$d"
  printf 'bogus 1\n' >"$d/start-one-player.keys"
  out="$(cd "$d" && LIVE_LANE=$((LANE_BASE + 1)) "$DRIVE" keys start-one-player.keys 2>&1)"
  [[ "$out" != *"unknown key"* ]] && [[ "$out" == *"not running"* ]]
}

t_explicit_path_uses_the_named_file() {
  local d="$TMP/explicit" out
  mkdir -p "$d"
  printf 'bogus 1\n' >"$d/start-one-player.keys"
  out="$(cd "$d" && LIVE_LANE=$((LANE_BASE + 1)) "$DRIVE" keys ./start-one-player.keys 2>&1)"
  [[ "$out" == *"unknown key"* ]]
}

check "item 1: a key script does not glob" t_glob_in_key_script
check "item 2: an empty script is a no-op" t_empty_script_is_a_noop
check "item 3: empty combo parts are rejected with file:line" t_rejects_empty_combo_parts
check "item 4: README lists u, i, o, p" t_readme_lists_every_accepted_key
check "item 5: stop spares a foreign pid" t_stop_spares_a_foreign_pid
check "item 5: start ignores a foreign pid" t_start_ignores_a_foreign_pid
check "item 6: stop kills a background record" t_stop_kills_a_background_recorder
check "item 6: terminating smoke leaves no recorder or Xvfb" t_terminated_smoke_leaves_no_recorder
check "item 6: stop cleans up after a killed smoke" t_stop_cleans_up_after_a_killed_smoke
check "item 7: two lanes write to separate folders" t_lanes_run_side_by_side
check "item 8: stop removes logs after a clean run" t_stop_removes_logs_after_a_clean_run
check "item 8: a failed start keeps logs and names them" t_failed_start_keeps_logs_and_says_where
check "item 9: smoke rejects other screen sizes" t_smoke_rejects_other_screen_sizes
check "item 9: start fails when no window appears" t_start_fails_without_a_window
check "item 9: stop escalates to KILL" t_stop_escalates_to_kill
check "item 9: start spares a held display lock" t_start_spares_a_held_display_lock
check "lanes: start waits for a slow Xvfb" t_start_waits_for_a_slow_xvfb
check "item 9: a non-numeric LIVE_LANE is rejected" t_rejects_a_non_numeric_lane
check "item 9: a failed smoke leaves the frame and game.log" t_failed_smoke_leaves_artifacts
check "item 10: a bare name does not pick up the current directory first" t_smoke_ignores_a_script_in_the_current_directory
check "item 10: an explicit path uses the named file" t_explicit_path_uses_the_named_file

[ "$failures" = 0 ] || {
  echo "$failures check(s) failed"
  exit 1
}
echo "all checks passed"
