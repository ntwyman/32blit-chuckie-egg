#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2020-2026 ntwyman
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LIVE="$ROOT/tools/live"

LANE="${LIVE_LANE:-0}"
DISPLAY_NUM="${LIVE_DISPLAY:-$((99 + LANE))}"
SCREEN="${LIVE_SCREEN:-640x480x24}"
BIN="${LIVE_BIN:-$ROOT/build.sdl/chuckie-egg}"
STATE="${LIVE_STATE:-${TMPDIR:-/tmp}/chuckie-live-$DISPLAY_NUM}"
OUT_DIR="${LIVE_OUT_DIR:-$LIVE/out}"
GOLDEN="${LIVE_GOLDEN:-$LIVE/golden/level1-start.png}"
SMOKE_ATTEMPTS="${LIVE_SMOKE_ATTEMPTS:-3}"
SMOKE_FPS=100

export DISPLAY=":$DISPLAY_NUM"
export SDL_AUDIODRIVER=dummy

die() {
  echo "drive.sh: $*" >&2
  exit 1
}

pid_alive() {
  [ -s "$1" ] && kill -0 "$(cat "$1")" 2>/dev/null
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

cmd_start() {
  need Xvfb xdotool
  [ -x "$BIN" ] || die "no game binary at $BIN; build it with: cmake -B build.sdl && cmake --build build.sdl -j"
  if game_running; then
    echo "start: game already running (pid $(cat "$STATE/game.pid"), display $DISPLAY)"
    return 0
  fi
  mkdir -p "$STATE"
  if ! display_up; then
    rm -f "/tmp/.X${DISPLAY_NUM}-lock"
    Xvfb "$DISPLAY" -screen 0 "$SCREEN" >"$STATE/xvfb.log" 2>&1 &
    echo $! >"$STATE/xvfb.pid"
    local i
    for i in $(seq 1 50); do
      display_up && break
      sleep 0.1
    done
    display_up || die "Xvfb did not come up on $DISPLAY, see $STATE/xvfb.log"
  fi
  "$BIN" >"$STATE/game.log" 2>&1 &
  echo $! >"$STATE/game.pid"
  local i
  for i in $(seq 1 100); do
    game_running || die "game exited at startup, see $STATE/game.log"
    xdotool search --onlyvisible --name 'Chuckie Egg' >/dev/null 2>&1 && break
    sleep 0.1
  done
  sleep 1
  echo "start: game running (pid $(cat "$STATE/game.pid"), display $DISPLAY)"
}

cmd_stop() {
  local did=0 f
  for f in game xvfb; do
    if pid_alive "$STATE/$f.pid"; then
      kill "$(cat "$STATE/$f.pid")" 2>/dev/null || true
      did=1
    fi
    rm -f "$STATE/$f.pid"
  done
  if [ "$did" = 1 ]; then
    sleep 0.3
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

# Prints "<xdotool key>[+<xdotool key>] <hold-ms>" or "wait <ms>" for each step, or exits 2 naming the first bad line.
parse_keys() {
  local file="$1" n=0 line key arg extra part xk names
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
    names=""
    for part in ${key//+/ }; do
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
  if [ -f "$s" ]; then
    echo "$s"
  elif [ -f "$LIVE/scripts/$s" ]; then
    echo "$LIVE/scripts/$s"
  elif [ -f "$LIVE/scripts/$s.keys" ]; then
    echo "$LIVE/scripts/$s.keys"
  else
    die "no key script '$s'"
  fi
}

ms_sleep() {
  sleep "$(awk -v ms="$1" 'BEGIN { printf "%.3f", ms / 1000 }')"
}

cmd_keys() {
  [ $# -eq 1 ] || die "usage: drive.sh keys <script>"
  need xdotool
  local file steps key ms
  file="$(resolve_script "$1")"
  steps="$(parse_keys "$file")" || exit 2
  game_running || die "game is not running, run: drive.sh start"
  while read -r key ms; do
    if [ "$key" = wait ]; then
      ms_sleep "$ms"
    else
      xdotool keydown ${key//+/ }
      ms_sleep "$ms"
      xdotool keyup ${key//+/ }
    fi
  done <<<"$steps"
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
  mkdir -p "$(dirname "$2")"
  ffmpeg -nostdin -loglevel error -y -f x11grab -framerate 30 -video_size "${SCREEN%x*}" -i "$DISPLAY" \
    -t "$1" -c:v libx264 -pix_fmt yuv420p "$2"
}

frame_hashes() {
  ffmpeg -nostdin -loglevel error -i "$1" -vf format=rgb24 -f framemd5 - | awk -F', *' '!/^#/ { print $NF }'
}

# Records the screen while the one-player script runs, so one of the frames
# shows the first rendered state of level 1.
record_start() {
  local video="$1" rec
  ffmpeg -nostdin -loglevel error -y -f x11grab -framerate "$SMOKE_FPS" -video_size "${SCREEN%x*}" -i "$DISPLAY" \
    -c:v ffv1 "$video" &
  rec=$!
  sleep 0.5
  cmd_keys start-one-player.keys
  sleep 0.4
  kill -INT "$rec" 2>/dev/null || true
  wait "$rec" 2>/dev/null || true
}

frame_png() {
  ffmpeg -nostdin -loglevel error -y -i "$1" -vf "select=eq(n\,$2)" -vframes 1 "$3"
}

smoke_attempt() {
  local video="$STATE/smoke.mkv" want hashes idx
  cmd_stop >/dev/null
  cmd_start >/dev/null
  record_start "$video"
  cmd_stop >/dev/null
  want="$(frame_hashes "$GOLDEN")"
  hashes="$(frame_hashes "$video")"
  idx="$(grep -n -x -m1 "$want" <<<"$hashes" | cut -d: -f1 || true)"
  [ -n "$idx" ] || return 1
  mkdir -p "$OUT_DIR"
  frame_png "$video" "$((idx - 1))" "$OUT_DIR/smoke.png"
}

cmd_smoke() {
  need Xvfb xdotool ffmpeg compare
  [ -f "$GOLDEN" ] || die "no golden image at $GOLDEN"
  trap 'cmd_stop >/dev/null' EXIT
  local attempt diff
  for attempt in $(seq 1 "$SMOKE_ATTEMPTS"); do
    if smoke_attempt; then
      diff="$(compare -metric AE "$OUT_DIR/smoke.png" "$GOLDEN" null: 2>&1 || true)"
      if [ "$diff" = 0 ]; then
        echo "smoke: ok"
        echo "smoke.png: $OUT_DIR/smoke.png" >&2
        return 0
      fi
      echo "smoke: attempt $attempt: $diff pixels differ from the golden image" >&2
    else
      echo "smoke: attempt $attempt: no recorded frame matches the golden image" >&2
    fi
  done
  echo "smoke: FAILED after $SMOKE_ATTEMPTS attempts, game log: $STATE/game.log" >&2
  return 1
}

# Saves the first rendered frame of level 1 as the golden image.
cmd_golden() {
  [ $# -eq 1 ] || die "usage: drive.sh golden <path>"
  need Xvfb xdotool ffmpeg
  trap 'cmd_stop >/dev/null' EXIT
  local video="$STATE/golden.mkv" hashes idx
  cmd_stop >/dev/null
  cmd_start >/dev/null
  record_start "$video"
  hashes="$(frame_hashes "$video")"
  idx="$(awk '$0 != prev { runs++; if (runs == 3) { print NR - 1; exit } } { prev = $0 }' <<<"$hashes")"
  [ -n "$idx" ] || die "golden: the recording has no frame after the how-many and ready screens"
  mkdir -p "$(dirname "$1")"
  frame_png "$video" "$idx" "$1"
  echo "golden: wrote $1 from frame $((idx + 1))"
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
      echo "usage: drive.sh start | keys <script> | shot <path> | record <seconds> <path> | stop | smoke | golden <path>" >&2
      exit 2
      ;;
  esac
}

main "$@"
