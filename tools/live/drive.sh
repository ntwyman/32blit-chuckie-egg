#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2020-2026 ntwyman
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIVE="$ROOT/tools/live"

die() {
  echo "drive.sh: $*" >&2
  exit 1
}

bounded_var() {
  local name="$1" value="$2" max="$3"
  if ! [[ "$value" =~ ^[0-9]{1,9}$ ]] || [ "$((10#$value))" -gt "$max" ]; then
    die "$name must be a whole number from 0 to $max, got '$value'"
  fi
  echo "$((10#$value))"
}

LANE="$(bounded_var LIVE_LANE "${LIVE_LANE:-0}" 899)"
DISPLAY_NUM="$(bounded_var LIVE_DISPLAY "${LIVE_DISPLAY:-$((99 + LANE))}" 65535)"
SCREEN="${LIVE_SCREEN:-640x480x24}"
BIN="${LIVE_BIN:-$ROOT/build.sdl/chuckie-egg}"
STATE="${LIVE_STATE:-${TMPDIR:-/tmp}/chuckie-live-$DISPLAY_NUM}"
OUT_DIR="${LIVE_OUT_DIR:-$LIVE/out/lane$LANE}"
GOLDEN="${LIVE_GOLDEN:-$LIVE/golden/level1-start.png}"
SMOKE_ATTEMPTS="$(bounded_var LIVE_SMOKE_ATTEMPTS "${LIVE_SMOKE_ATTEMPTS:-5}" 1000)"
WINDOW_WAIT="$(bounded_var LIVE_WINDOW_WAIT "${LIVE_WINDOW_WAIT:-10}" 3600)"
SMOKE_FPS=100
SMOKE_SCREEN=640x480x24

export DISPLAY=":$DISPLAY_NUM"
export SDL_AUDIODRIVER=dummy

proc_stat() {
  local stat
  stat="$(cat "/proc/$1/stat" 2>/dev/null)" || return 1
  stat="${stat##*) }"
  set -f
  set -- $stat
  set +f
  echo "$1 ${20}"
}

record_pid() {
  echo "$2 $(proc_stat "$2" | cut -d' ' -f2)" >"$1"
}

pid_alive() {
  local pid="" started="" now
  [ -s "$1" ] && read -r pid started <"$1" || return 1
  [ -n "$started" ] || return 1
  now="$(proc_stat "$pid")" || return 1
  [ "${now%% *}" != Z ] && [ "${now##* }" = "$started" ]
}

pid_of() {
  cut -d' ' -f1 "$1"
}

stop_proc() {
  local file="$1" sig="${2:-TERM}" pid i
  if ! pid_alive "$file"; then
    rm -f "$file"
    return 1
  fi
  pid="$(pid_of "$file")"
  kill "-$sig" "$pid" 2>/dev/null || true
  for i in $(seq 1 30); do
    pid_alive "$file" || break
    sleep 0.1
  done
  if pid_alive "$file"; then
    kill -KILL "$pid" 2>/dev/null || true
    for i in $(seq 1 30); do
      pid_alive "$file" || break
      sleep 0.1
    done
    pid_alive "$file" && echo "drive.sh: pid $pid did not exit after KILL" >&2
  fi
  wait "$pid" 2>/dev/null || true
  rm -f "$file"
  return 0
}

display_up() {
  xdotool getdisplaygeometry >/dev/null 2>&1
}

need() {
  local tool
  for tool in "$@"; do
    command -v "$tool" >/dev/null || die "missing tool: $tool"
  done
}

game_running() {
  pid_alive "$STATE/game.pid"
}

keep_logs() {
  : >"$STATE/failed"
}

window_up() {
  xdotool search --onlyvisible --name 'Chuckie Egg' >/dev/null 2>&1
}

build_level() {
  local level="$1" dir="$ROOT/build.sdl-level$1"
  mkdir -p "$STATE"
  echo "start: building $dir with CHUCKIE_START_LEVEL=$level" >&2
  if ! { cmake -B "$dir" -S "$ROOT" -DCHUCKIE_START_LEVEL="$level" && cmake --build "$dir" -j; } >"$STATE/build.log" 2>&1; then
    keep_logs
    die "the level $level build failed, see $STATE/build.log"
  fi
  BIN="$dir/chuckie-egg"
}

cmd_start() {
  if [ $# -gt 0 ]; then
    [ $# -eq 2 ] && [ "$1" = --level ] || {
      echo "usage: drive.sh start [--level <n>]" >&2
      exit 2
    }
    [[ "$2" =~ ^[1-9][0-9]{0,2}$ ]] && [ "$2" -le 256 ] || {
      echo "drive.sh: --level must be a whole number from 1 to 256, got '$2'" >&2
      exit 2
    }
    [ -z "${LIVE_BIN:-}" ] || die "start --level builds its own binary, so unset LIVE_BIN"
  fi
  need Xvfb xdotool stdbuf
  if game_running; then
    [ $# -eq 0 ] || die "a game already runs on display $DISPLAY and may be on another level; run drive.sh stop first"
    echo "start: game already running (pid $(pid_of "$STATE/game.pid"), display $DISPLAY)"
    return 0
  fi
  [ $# -eq 0 ] || build_level "$2"
  [ -x "$BIN" ] || die "no game binary at $BIN; build it with: cmake -B build.sdl && cmake --build build.sdl -j"
  mkdir -p "$STATE"
  rm -f "$STATE/failed"
  if ! display_up; then
    local lock="/tmp/.X${DISPLAY_NUM}-lock" holder=""
    if [ -f "$lock" ]; then
      holder="$(tr -d ' \n' <"$lock" 2>/dev/null || true)"
      if [[ "$holder" =~ ^[0-9]+$ ]] && [ -d "/proc/$holder" ]; then
        die "display $DISPLAY is held by pid $holder but does not answer; stop that process or set LIVE_LANE"
      fi
      rm -f "$lock"
    fi
    Xvfb "$DISPLAY" -screen 0 "$SCREEN" -noreset >"$STATE/xvfb.log" 2>&1 &
    record_pid "$STATE/xvfb.pid" $!
    local i
    for i in $(seq 1 $((WINDOW_WAIT * 10))); do
      display_up && break
      pid_alive "$STATE/xvfb.pid" || break
      sleep 0.1
    done
    if ! display_up; then
      keep_logs
      stop_procs || true
      die "Xvfb did not answer on $DISPLAY within ${WINDOW_WAIT}s, see $STATE/xvfb.log"
    fi
  fi
  stdbuf -oL "$BIN" >"$STATE/game.log" 2>&1 &
  record_pid "$STATE/game.pid" $!
  local i found=0
  for i in $(seq 1 $((WINDOW_WAIT * 10))); do
    if ! game_running; then
      keep_logs
      stop_procs || true
      die "game exited at startup, see $STATE/game.log"
    fi
    if window_up; then
      found=1
      break
    fi
    sleep 0.1
  done
  if [ "$found" = 0 ]; then
    keep_logs
    stop_procs || true
    die "no game window on $DISPLAY after ${WINDOW_WAIT}s, see $STATE/game.log"
  fi
  sleep 1
  echo "start: game running (pid $(pid_of "$STATE/game.pid"), display $DISPLAY)"
}

stop_procs() {
  local did=1
  stop_proc "$STATE/rec.pid" INT && did=0
  stop_proc "$STATE/record.pid" INT && did=0
  stop_proc "$STATE/game.pid" && did=0
  stop_proc "$STATE/xvfb.pid" && did=0
  return "$did"
}

cmd_stop() {
  local did=0
  stop_procs && did=1
  rm -f "$STATE"/*.mkv "$STATE"/*.err
  if [ -e "$STATE/failed" ]; then
    echo "stop: a run failed; logs are in $STATE" >&2
  else
    rm -f "$STATE/game.log" "$STATE/xvfb.log"
    rmdir "$STATE" 2>/dev/null || true
  fi
  if [ "$did" = 1 ]; then
    echo "stop: stopped"
  else
    echo "stop: nothing running"
  fi
}

xdotool_key() {
  case "$1" in
    up) echo Up ;;
    down) echo Down ;;
    left) echo Left ;;
    right) echo Right ;;
    esc | escape) echo Escape ;;
    [zxcvwasduiop123]) echo "$1" ;;
    *) return 1 ;;
  esac
}

parse_keys() {
  local file="$1" n=0 line key arg extra part xk names
  local -a parts
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    line="${line%%#*}"
    key="" arg="" extra=""
    read -r key arg extra <<<"$line" || true
    [ -z "$key" ] && continue
    if [ -z "$arg" ] || [ -n "$extra" ] || ! [[ "$arg" =~ ^[0-9]+$ ]]; then
      echo "drive.sh: $file:$n: expected '<key> <hold-ms>' or 'wait <ms>', got '$line'" >&2
      return 2
    fi
    if [ "$key" = wait ]; then
      echo "wait $arg"
      continue
    fi
    if [[ "$key" == +* || "$key" == *+ || "$key" == *++* ]]; then
      echo "drive.sh: $file:$n: empty key in combo '$key'" >&2
      return 2
    fi
    IFS=+ read -ra parts <<<"$key"
    names=""
    for part in "${parts[@]}"; do
      xk="$(xdotool_key "$part")" || {
        echo "drive.sh: $file:$n: unknown key '$part'" >&2
        return 2
      }
      names="$names${names:+ }$xk"
    done
    echo "${names// /+} $arg"
  done <"$file"
}

resolve_script() {
  local s="$1"
  if [[ "$s" == */* ]]; then
    [ -f "$s" ] || die "no key script at '$s'"
    echo "$s"
  elif [ -f "$LIVE/scripts/$s" ]; then
    echo "$LIVE/scripts/$s"
  elif [ -f "$LIVE/scripts/$s.keys" ]; then
    echo "$LIVE/scripts/$s.keys"
  elif [ -f "$s" ]; then
    echo "./$s"
  else
    die "no key script '$s'"
  fi
}

ms_sleep() {
  sleep "$(awk -v ms="$1" 'BEGIN { printf "%.3f", ms / 1000 }')"
}

HELD_KEYS=""

release_held() {
  [ -z "${HOLD_PID:-}" ] || kill "$HOLD_PID" 2>/dev/null || true
  [ -z "$HELD_KEYS" ] || xdotool keyup ${HELD_KEYS//+/ } 2>/dev/null || true
  HELD_KEYS=""
}

hold_for() {
  sleep "$(awk -v ms="$1" 'BEGIN { printf "%.3f", ms / 1000 }')" &
  HOLD_PID=$!
  wait "$HOLD_PID"
  HOLD_PID=""
}

cmd_keys() {
  [ $# -eq 1 ] || die "usage: drive.sh keys <script>"
  need xdotool
  local file steps key ms saved
  file="$(resolve_script "$1")"
  steps="$(parse_keys "$file")" || exit 2
  [ -n "$steps" ] || return 0
  game_running || die "game is not running, run: drive.sh start"
  saved=""
  if [ "$BASHPID" = "$$" ]; then
    saved="$(trap -p INT TERM EXIT)"
  fi
  trap 'release_held' EXIT
  trap 'release_held; trap - INT TERM EXIT; eval "$saved"; kill -s INT $BASHPID' INT
  trap 'release_held; trap - INT TERM EXIT; eval "$saved"; kill -s TERM $BASHPID' TERM
  while read -r key ms; do
    if [ "$key" = wait ]; then
      ms_sleep "$ms"
    else
      HELD_KEYS="$key"
      xdotool keydown ${key//+/ }
      hold_for "$ms"
      release_held
    fi
  done <<<"$steps"
  trap - INT TERM EXIT
  eval "$saved"
}

cmd_shot() {
  [ $# -eq 1 ] || die "usage: drive.sh shot <path>"
  need import
  display_up || die "no display $DISPLAY, run: drive.sh start"
  mkdir -p "$(dirname "$1")"
  import -window root "$1"
}

cmd_record() {
  [ $# -eq 2 ] || die "usage: drive.sh record <seconds> <path>"
  need ffmpeg
  display_up || die "no display $DISPLAY, run: drive.sh start"
  mkdir -p "$(dirname "$2")" "$STATE"
  local rc=0
  ffmpeg -nostdin -loglevel error -y -f x11grab -draw_mouse 0 -framerate 30 -video_size "${SCREEN%x*}" -i "$DISPLAY" \
    -t "$1" -c:v libx264 -pix_fmt yuv420p "$2" &
  record_pid "$STATE/record.pid" $!
  wait $! || rc=$?
  rm -f "$STATE/record.pid"
  [ "$rc" = 0 ] || [ "$rc" = 255 ]
}

frame_hashes() {
  ffmpeg -nostdin -loglevel error -i "$1" -vf format=rgb24 -f framemd5 - | awk -F', *' '!/^#/ { print $NF }'
}

level1_frames() {
  awk '$0 != prev { runs++; if (runs == 2) ready = NR - 1; if (runs == 3) { print ready, NR - 1; exit } } { prev = $0 }'
}

record_start() {
  local video="$1"
  ffmpeg -nostdin -loglevel error -y -f x11grab -draw_mouse 0 -framerate "$SMOKE_FPS" -video_size "${SCREEN%x*}" -i "$DISPLAY" \
    -c:v ffv1 "$video" &
  record_pid "$STATE/rec.pid" $!
  sleep 0.5
  if ! (cmd_keys "$LIVE/scripts/start-one-player.keys"); then
    return 1
  fi
  sleep 0.4
  if ! pid_alive "$STATE/rec.pid"; then
    echo "the recorder died before the keys finished" >&2
    return 1
  fi
  stop_proc "$STATE/rec.pid" INT || true
}

frame_png() {
  ffmpeg -nostdin -loglevel error -y -i "$1" -vf "select=eq(n\,$2)" -vframes 1 "$3"
}

need_smoke_screen() {
  [ "$SCREEN" = "$SMOKE_SCREEN" ] || die "smoke and golden need LIVE_SCREEN=$SMOKE_SCREEN exactly, got LIVE_SCREEN=$SCREEN"
}

smoke_attempt() {
  local video="$STATE/smoke.mkv" hashes frames
  stop_procs || true
  rm -f "$video"
  mkdir -p "$OUT_DIR"
  (cmd_start >/dev/null) || {
    echo "the game did not start" >&2
    return 1
  }
  record_start "$video" || return 1
  stop_procs || true
  [ -s "$video" ] || {
    echo "the recording is empty" >&2
    return 1
  }
  hashes="$(frame_hashes "$video")"
  frames="$(level1_frames <<<"$hashes")"
  if [ -z "$frames" ]; then
    frame_png "$video" "$(($(wc -l <<<"$hashes") - 1))" "$OUT_DIR/smoke.png" || true
    echo "no level-1 frame in $(wc -l <<<"$hashes") recorded frames; the last one is in $OUT_DIR/smoke.png" >&2
    return 1
  fi
  frame_png "$video" "${frames#* }" "$OUT_DIR/smoke.png" || {
    echo "could not extract frame ${frames#* }" >&2
    return 1
  }
  echo "smoke: selected frame ${frames#* }, $((${frames#* } - ${frames% *})) frames after the ready screen first showed" >&2
}

cmd_smoke() {
  need Xvfb xdotool ffmpeg compare
  need_smoke_screen
  [ -f "$GOLDEN" ] || die "no golden image at $GOLDEN"
  trap 'cmd_stop >/dev/null' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  local attempt diff why="$STATE/attempt.err"
  mkdir -p "$STATE"
  for attempt in $(seq 1 "$SMOKE_ATTEMPTS"); do
    if smoke_attempt 2>"$why"; then
      cat "$why" >&2
      diff="$(compare -metric AE "$OUT_DIR/smoke.png" "$GOLDEN" null: 2>&1 || true)"
      if [ "$diff" = 0 ]; then
        echo "smoke: ok"
        echo "smoke.png: $OUT_DIR/smoke.png" >&2
        return 0
      fi
      keep_logs
      cp -f "$STATE/game.log" "$OUT_DIR/game.log" 2>/dev/null || true
      echo "smoke: FAILED, $diff pixels differ from the golden image; frame: $OUT_DIR/smoke.png, game log: $STATE/game.log" >&2
      return 1
    fi
    if [ "$attempt" -lt "$SMOKE_ATTEMPTS" ]; then
      echo "smoke: attempt $attempt of $SMOKE_ATTEMPTS: run failed, retrying: $(tr '\n' ' ' <"$why")" >&2
    else
      echo "smoke: attempt $attempt of $SMOKE_ATTEMPTS: run failed, no attempts remain: $(tr '\n' ' ' <"$why")" >&2
    fi
  done
  keep_logs
  cp -f "$STATE/game.log" "$OUT_DIR/game.log" 2>/dev/null || true
  echo "smoke: FAILED, $SMOKE_ATTEMPTS runs failed, game log: $STATE/game.log" >&2
  return 1
}

golden_exit() {
  if [ "$1" != 0 ]; then
    mkdir -p "$STATE"
    keep_logs
  fi
  cmd_stop >/dev/null
}

cmd_golden() {
  [ $# -eq 1 ] || die "usage: drive.sh golden <path>"
  need Xvfb xdotool ffmpeg
  need_smoke_screen
  trap 'golden_exit $?' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  local video="$STATE/golden.mkv" hashes frames
  cmd_stop >/dev/null
  cmd_start >/dev/null
  record_start "$video"
  hashes="$(frame_hashes "$video")"
  frames="$(level1_frames <<<"$hashes")"
  [ -n "$frames" ] || die "golden: the recording has no frame after the how-many and ready screens"
  mkdir -p "$(dirname "$1")"
  frame_png "$video" "${frames#* }" "$1"
  echo "golden: wrote $1 from frame $((${frames#* } + 1))"
}

main() {
  local cmd="${1:-}"
  [ $# -gt 0 ] && shift
  case "$cmd" in
    start) cmd_start "$@" ;;
    keys) cmd_keys "$@" ;;
    shot) cmd_shot "$@" ;;
    record) cmd_record "$@" ;;
    stop) cmd_stop "$@" ;;
    smoke) cmd_smoke "$@" ;;
    golden) cmd_golden "$@" ;;
    *)
      echo "usage: drive.sh start [--level <n>] | keys <script> | shot <path> | record <seconds> <path> | stop | smoke | golden <path>" >&2
      exit 2
      ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
