#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2020-2026 ntwyman
set -uo pipefail

LIVE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DRIVE="${DRIVE:-$LIVE/drive.sh}"
TMP="$(mktemp -d)"
LANE_BASE="${LIVE_TEST_LANE_BASE:-10}"
LANES="$(seq "$LANE_BASE" "$((LANE_BASE + 9))")"
ARTIFACTS="${LIVE_TEST_ARTIFACTS:-$LIVE/out/test-drive}"
failures=0

keep_artifacts() {
  local lane="$1" state="/tmp/chuckie-live-$((99 + $1))"
  [ -d "$LIVE/out/lane$lane" ] && cp -r "$LIVE/out/lane$lane" "$ARTIFACTS/lane$lane"
  [ -d "$state" ] && cp -r "$state" "$ARTIFACTS/state-lane$lane"
  return 0
}

cleanup() {
  local lane
  [ "$failures" = 0 ] || mkdir -p "$ARTIFACTS/logs"
  for lane in $LANES; do
    LIVE_LANE=$lane "$DRIVE" stop >/dev/null 2>&1
    [ "$failures" = 0 ] || keep_artifacts "$lane"
    rm -rf "/tmp/chuckie-live-$((99 + lane))" "$LIVE/out/lane$lane"
  done
  [ "$failures" = 0 ] || cp "$TMP"/*.log "$ARTIFACTS/logs/" 2>/dev/null
  pkill -f "$TMP/" 2>/dev/null
  rm -rf "$TMP"
}
trap cleanup EXIT

check() {
  local name="$1"
  shift
  [ -z "${LIVE_TEST_ONLY:-}" ] || [ "$name" = "$LIVE_TEST_ONLY" ] || return 0
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
  for key in up down left right w a s d z x c v u i o p 1 2 3 esc escape; do
    grep -q "^| .*\`$key\`" "$LIVE/README.md" || return 1
  done
}

t_readme_has_no_stale_heap_garbage_note() {
  ! grep -q 'heap garbage\|Until that is fixed' "$LIVE/README.md"
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

key_is_down() {
  python3 -I -c '
import ctypes, ctypes.util, sys
x = ctypes.CDLL(ctypes.util.find_library("X11"))
x.XOpenDisplay.restype = ctypes.c_void_p
x.XOpenDisplay.argtypes = [ctypes.c_char_p]
x.XStringToKeysym.restype = ctypes.c_ulong
x.XKeysymToKeycode.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
x.XQueryKeymap.argtypes = [ctypes.c_void_p, ctypes.c_char * 32]
d = x.XOpenDisplay(sys.argv[1].encode())
kc = x.XKeysymToKeycode(d, x.XStringToKeysym(sys.argv[2].encode()))
buf = (ctypes.c_char * 32)()
x.XQueryKeymap(d, buf)
print(1 if buf.raw[kc // 8] & (1 << (kc % 8)) else 0)
' ":$((99 + $1))" "$2"
}

t_terminated_keys_release_the_held_key() {
  local lane=$((LANE_BASE + 2)) keys pid held=0 after
  printf 'z 20000\n' >"$TMP/hold.keys"
  LIVE_LANE=$lane "$DRIVE" start >/dev/null 2>&1 || return 1
  LIVE_LANE=$lane "$DRIVE" keys "$TMP/hold.keys" >/dev/null 2>&1 &
  keys=$!
  for _ in $(seq 1 50); do
    [ "$(key_is_down $lane z)" = 1 ] && { held=1; break; }
    sleep 0.1
  done
  kill -TERM "$keys"
  wait "$keys" 2>/dev/null
  sleep 0.3
  after="$(key_is_down $lane z)"
  LIVE_LANE=$lane "$DRIVE" stop >/dev/null 2>&1
  [ "$held" = 1 ] && [ "$after" = 0 ]
}

t_keys_in_a_subshell_leave_the_callers_exit_trap_alone() {
  printf 'wait 10\n' >"$TMP/wait.keys"
  bash -c '
    source "$1"
    game_running() { return 0; }
    trap "touch \"$2\"" EXIT
    (cmd_keys "$3")
    trap - EXIT
    [ ! -e "$2" ]
  ' _ "$DRIVE" "$TMP/trap-fired" "$TMP/wait.keys"
}

t_numbers_parse_as_decimal() {
  local out
  [ "$(LIVE_LANE=0$LANE_BASE bash -c 'source "$1"; echo "$LANE"' _ "$DRIVE")" = "$LANE_BASE" ] || return 1
  [ "$(LIVE_LANE=0$LANE_BASE bash -c 'source "$1"; echo "$DISPLAY"' _ "$DRIVE")" = ":$((99 + LANE_BASE))" ] || return 1
  [ "$(LIVE_WINDOW_WAIT=08 bash -c 'source "$1"; echo "$WINDOW_WAIT"' _ "$DRIVE")" = 8 ] || return 1
  out="$(LIVE_LANE=00000000000000000000000 "$DRIVE" stop 2>&1)"
  [ $? != 0 ] && [[ "$out" == *"LIVE_LANE must be"* ]] || return 1
  out="$(LIVE_LANE=900 "$DRIVE" stop 2>&1)"
  [ $? != 0 ] && [[ "$out" == *"0 to 899"* ]] || return 1
  out="$(LIVE_WINDOW_WAIT=99999999999999999999 "$DRIVE" stop 2>&1)"
  [ $? != 0 ] && [[ "$out" == *"LIVE_WINDOW_WAIT must be"* ]]
}

t_start_spares_a_lock_held_by_another_user() {
  local lane=$((LANE_BASE + 8)) lock rc kept=0
  kill -0 1 2>/dev/null && return 0
  lock="/tmp/.X$((99 + lane))-lock"
  printf '%10d\n' 1 >"$lock"
  LIVE_LANE=$lane "$DRIVE" start >/dev/null 2>&1
  rc=$?
  [ -f "$lock" ] && kept=1
  rm -f "$lock"
  LIVE_LANE=$lane "$DRIVE" stop >/dev/null 2>&1
  [ "$rc" != 0 ] && [ "$kept" = 1 ]
}

t_smoke_needs_the_exact_screen() {
  local screen out
  for screen in 640x480 640x480x16; do
    out="$(LIVE_LANE=$((LANE_BASE + 7)) LIVE_SCREEN=$screen LIVE_SMOKE_ATTEMPTS=1 "$DRIVE" smoke 2>&1)"
    [ $? != 0 ] && [[ "$out" == *"640x480x24"* ]] || return 1
  done
}

t_last_attempt_does_not_say_retrying() {
  local lane=$((LANE_BASE + 6)) out
  printf '#!/bin/sh\nexit 1\n' >"$TMP/crash-fast.sh"
  chmod +x "$TMP/crash-fast.sh"
  out="$(LIVE_LANE=$lane LIVE_BIN="$TMP/crash-fast.sh" LIVE_OUT_DIR="$TMP/last" LIVE_SMOKE_ATTEMPTS=2 "$DRIVE" smoke 2>&1)"
  [ $? != 0 ] || return 1
  [[ "$out" == *"attempt 1 of 2: run failed, retrying"* ]] || return 1
  [[ "$out" == *"attempt 2 of 2: run failed, no attempts remain"* ]] && [[ "$out" != *"attempt 2 of 2: run failed, retrying"* ]]
}

t_failed_golden_keeps_logs() {
  local lane=$((LANE_BASE + 7)) state out rc
  state="$(lane_state $lane)"
  out="$(LIVE_LANE=$lane "$DRIVE" golden /proc/no-such-dir/golden.png 2>&1)"
  rc=$?
  [ -e "$state/game.log" ] && [[ "$out" == *"$state"* ]] && [ "$rc" != 0 ]
  local ok=$?
  LIVE_LANE=$lane "$DRIVE" stop >/dev/null 2>&1
  return $ok
}

t_failing_checks_leave_artifacts() {
  local lane=$((LANE_BASE + 10)) art="$TMP/artifacts" fake="$TMP/fake-drive.sh" rc
  printf '#!/bin/bash\ns=/tmp/chuckie-live-$((99 + LIVE_LANE))\nmkdir -p "$s" "%s/out/lane$LIVE_LANE"\necho state >"$s/game.log"\necho frame >"%s/out/lane$LIVE_LANE/smoke.png"\nexit 1\n' "$LIVE" "$LIVE" >"$fake"
  chmod +x "$fake"
  LIVE_TEST_ONLY="item 2: an empty script is a no-op" LIVE_TEST_ARTIFACTS="$art" LIVE_TEST_LANE_BASE=$lane DRIVE="$fake" "$LIVE/test-drive.sh" >/dev/null 2>&1
  rc=$?
  [ "$rc" = 1 ] && [ -s "$art/state-lane$lane/game.log" ] && [ -s "$art/lane$lane/smoke.png" ]
}

t_ci_runs_smoke_after_failed_driver_tests() {
  local root="$LIVE/../.." step
  step="$(awk '/- name: Smoke test/ { on = 1; print; next } on && /- name:/ { exit } on { print }' "$root/.github/workflows/build.yml")"
  [[ "$step" == *"if:"* ]] && [[ "$step" == *"!cancelled()"* ]]
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

t_game_log_shows_debugf_while_running() {
  local lane=$((LANE_BASE + 2)) state i seen=no running=no
  state="$(lane_state $lane)"
  printf 'z 100\nwait 400\n' >"$TMP/tap-z.keys"
  for i in 1 2 3; do
    LIVE_LANE=$lane LIVE_WINDOW_WAIT=8 "$DRIVE" start >/dev/null 2>&1 && break
    LIVE_LANE=$lane "$DRIVE" stop >/dev/null 2>&1
    [ "$i" != 3 ] || return 1
  done
  for i in $(seq 1 40); do
    grep -q 'Loaded level' "$state/game.log" 2>/dev/null && seen=yes && break
    LIVE_LANE=$lane "$DRIVE" keys "$TMP/tap-z.keys" >/dev/null 2>&1
  done
  LIVE_LANE=$lane bash -c 'source "$1"; game_running' _ "$DRIVE" && running=yes
  if [ "$seen" != yes ] || [ "$running" != yes ]; then
    echo "  seen=$seen running=$running" >&2
    grep -av '^Step ' "$state/game.log" | head -20 >&2
    grep -ac '^Step ' "$state/game.log" >&2
  fi
  LIVE_LANE=$lane "$DRIVE" stop >/dev/null 2>&1
  [ "$seen" = yes ] && [ "$running" = yes ]
}

t_start_level_rejects_bad_values() {
  local lane=$((LANE_BASE + 1)) bad out
  for bad in 0 257 08 x "1 2" ""; do
    out="$(LIVE_LANE=$lane "$DRIVE" start --level "$bad" 2>&1)"
    [ $? = 2 ] && [[ "$out" == *"--level must be"* ]] || return 1
  done
  ! [ -e "$(lane_state $lane)/game.pid" ]
}

t_start_level_refuses_live_bin() {
  local out
  out="$(LIVE_LANE=$((LANE_BASE + 1)) LIVE_BIN=/bin/true "$DRIVE" start --level 2 2>&1)"
  [ $? = 1 ] && [[ "$out" == *"unset LIVE_BIN"* ]]
}

t_start_level_refuses_a_running_game() {
  local lane=$((LANE_BASE + 3)) out rc
  LIVE_LANE=$lane "$DRIVE" start >/dev/null 2>&1 || return 1
  out="$(LIVE_LANE=$lane "$DRIVE" start --level 2 2>&1)"
  rc=$?
  LIVE_LANE=$lane "$DRIVE" stop >/dev/null 2>&1
  [ "$rc" = 1 ] && [[ "$out" == *"run drive.sh stop first"* ]]
}

check "ce-3: game.log shows debugf lines while the game runs" t_game_log_shows_debugf_while_running
check "ce-3: start --level rejects bad values" t_start_level_rejects_bad_values
check "ce-3: start --level refuses a running game" t_start_level_refuses_a_running_game
check "ce-3: start --level refuses LIVE_BIN" t_start_level_refuses_live_bin
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
check "item 1: README has no stale heap garbage note" t_readme_has_no_stale_heap_garbage_note
check "item 4: the last attempt says no attempts remain" t_last_attempt_does_not_say_retrying
check "item 2: a terminated keys run releases the held key" t_terminated_keys_release_the_held_key
check "item 3: keys in a subshell leave the caller's EXIT trap alone" t_keys_in_a_subshell_leave_the_callers_exit_trap_alone
check "item 5: numbers parse as decimal and are bounded" t_numbers_parse_as_decimal
check "item 6: start spares a lock held by another user" t_start_spares_a_lock_held_by_another_user
check "item 7: smoke needs exactly 640x480x24" t_smoke_needs_the_exact_screen
check "item 8: CI runs smoke after failed driver tests" t_ci_runs_smoke_after_failed_driver_tests
check "item 8: failing checks leave frames and logs" t_failing_checks_leave_artifacts
check "item 9: a failed golden keeps logs" t_failed_golden_keeps_logs
check "item 10: a bare name does not pick up the current directory first" t_smoke_ignores_a_script_in_the_current_directory
check "item 10: an explicit path uses the named file" t_explicit_path_uses_the_named_file

[ "$failures" = 0 ] || {
  echo "$failures check(s) failed"
  exit 1
}
echo "all checks passed"
