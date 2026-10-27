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

build_variant() {
  local level="$1" score="$2" dir="$ROOT/build.sdl" flags=() what=""
  if [ -n "$level" ]; then
    dir+="-level$level"
    flags+=("-DCHUCKIE_START_LEVEL=$level")
    what+=" CHUCKIE_START_LEVEL=$level"
  fi
  if [ -n "$score" ]; then
    dir+="-score$score"
    flags+=("-DCHUCKIE_START_SCORE=$score")
    what+=" CHUCKIE_START_SCORE=$score"
  fi
  mkdir -p "$STATE"
  echo "start: building $dir with${what}" >&2
  if ! { cmake -B "$dir" -S "$ROOT" "${flags[@]}" && cmake --build "$dir" -j4; } >"$STATE/build.log" 2>&1; then
    keep_logs
    die "the${what} build failed, see $STATE/build.log"
  fi
  BIN="$dir/chuckie-egg"
}

cmd_start() {
  local level="" score="" variant=0
  while [ $# -gt 0 ]; do
    case "$1" in
      --level | --score)
        [ $# -ge 2 ] || {
          echo "usage: drive.sh start [--level <n>] [--score <n>]" >&2
          exit 2
        }
        if [ "$1" = --level ]; then
          [[ "$2" =~ ^[1-9][0-9]{0,2}$ ]] && [ "$2" -le 256 ] || {
            echo "drive.sh: --level must be a whole number from 1 to 256, got '$2'" >&2
            exit 2
          }
          level="$2"
        else
          [[ "$2" =~ ^(0|[1-9][0-9]{0,7})$ ]] || {
            echo "drive.sh: --score must be a whole number from 0 to 99999999, got '$2'" >&2
            exit 2
          }
          score="$2"
        fi
        variant=1
        shift 2
        ;;
      *)
        echo "usage: drive.sh start [--level <n>] [--score <n>]" >&2
        exit 2
        ;;
    esac
  done
  if [ "$variant" = 1 ]; then
    [ -z "${LIVE_BIN:-}" ] || die "start --level and --score build their own binary, so unset LIVE_BIN"
  fi
  need Xvfb xdotool stdbuf
  if game_running; then
    [ "$variant" = 0 ] || die "a game already runs on display $DISPLAY and may be on another level or score; run drive.sh stop first"
    echo "start: game already running (pid $(pid_of "$STATE/game.pid"), display $DISPLAY)"
    return 0
  fi
  [ "$variant" = 0 ] || build_variant "$level" "$score"
  [ -x "$BIN" ] || die "no game binary at $BIN; build it with: cmake -B build.sdl && cmake --build build.sdl -j4"
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
  local stepping=0
  for i in $(seq 1 $((WINDOW_WAIT * 10))); do
    game_running || break
    if grep -aq '^Step ' "$STATE/game.log"; then
      stepping=1
      break
    fi
    sleep 0.1
  done
  if [ "$stepping" = 0 ]; then
    keep_logs
    stop_procs || true
    die "the game opened a window but ran no step within ${WINDOW_WAIT}s, see $STATE/game.log"
  fi
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

RESTORE_TRAPS=""

install_cleanup() {
  local cleanup="$1" t exit_cmd=""
  RESTORE_TRAPS=""
  if [ "$BASHPID" = "$$" ]; then
    RESTORE_TRAPS="$(trap -p INT TERM EXIT)"
    t="$(trap -p EXIT)"
    if [ -n "$t" ]; then
      eval "set -- $t"
      exit_cmd="$3"
    fi
  fi
  trap "exit_status=\$?; set +e; $cleanup; (exit \$exit_status); $exit_cmd" EXIT
  trap "$cleanup; trap - INT TERM EXIT; eval \"\$RESTORE_TRAPS\"; kill -s INT \$BASHPID" INT
  trap "$cleanup; trap - INT TERM EXIT; eval \"\$RESTORE_TRAPS\"; kill -s TERM \$BASHPID" TERM
}

restore_traps() {
  trap - INT TERM EXIT
  eval "$RESTORE_TRAPS"
}

cmd_keys() {
  [ $# -eq 1 ] || die "usage: drive.sh keys <script>"
  need xdotool
  local file steps key ms
  file="$(resolve_script "$1")"
  steps="$(parse_keys "$file")" || exit 2
  [ -n "$steps" ] || return 0
  game_running || die "game is not running, run: drive.sh start"
  install_cleanup release_held
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
  restore_traps
}

parse_inputs() {
  local file="$1" n=0 line first rest part xk names
  local -a words parts
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    line="${line%%#*}"
    read -ra words <<<"$line" || true
    [ "${#words[@]}" -gt 0 ] || continue
    first="${words[0]}"
    case "$first" in
      level | score | players) continue ;;
    esac
    rest="${words[1]:--}"
    if ! [[ "$first" =~ ^[1-9][0-9]{0,6}$ ]] || [ "${#words[@]}" -gt 2 ]; then
      echo "drive.sh: $file:$n: expected '<frames> <keys>', got '$line'" >&2
      return 2
    fi
    names=""
    if [ "$rest" != - ]; then
      IFS=+ read -ra parts <<<"$rest"
      for part in "${parts[@]}"; do
        case "$part" in
          right) xk=Right ;;
          left) xk=Left ;;
          down) xk=Down ;;
          up) xk=Up ;;
          jump) xk=z ;;
          *)
            echo "drive.sh: $file:$n: the live driver cannot press '$part'; use right, left, down, up, or jump" >&2
            return 2
            ;;
        esac
        names="$names${names:+ }$xk"
      done
    fi
    echo "$first ${names:--}"
  done <"$file"
}

PLAY_STEP=0
PLAY_LATE=0

PLAY_PENDING=""

# Reads the next line of the game log, polling for it. tail -F polls once a second where inotify is missing, which
# delays every key by up to a second.
play_line() {
  local part polls=0
  while :; do
    if IFS= read -r -u "$PLAY_FD" part; then
      line="$PLAY_PENDING$part"
      PLAY_PENDING=""
      return 0
    fi
    PLAY_PENDING="$PLAY_PENDING$part"
    polls=$((polls + 1))
    [ "$polls" -lt 2500 ] || return 1
    sleep 0.002
  done
}

play_await() {
  local want="$1" line n
  while :; do
    play_line || die "play: no step in the game log for 5 seconds"
    [[ "$line" =~ ^Step\ ([0-9]+): ]] || continue
    n="${BASH_REMATCH[1]}"
    PLAY_STEP="$n"
    if [ "$n" -ge "$want" ]; then
      [ "$n" -eq "$want" ] || PLAY_LATE=$((PLAY_LATE + 1))
      return 0
    fi
  done
}

play_set() {
  local key keep=""
  for key in $HELD_KEYS; do
    if [[ " $1 " == *" $key "* ]]; then
      keep="$keep${keep:+ }$key"
    else
      echo "keyup $key" >&"$PLAY_XFD"
    fi
  done
  HELD_KEYS="$keep"
  for key in $1; do
    [[ " $HELD_KEYS " == *" $key "* ]] && continue
    echo "keydown $key" >&"$PLAY_XFD"
    HELD_KEYS="$HELD_KEYS${HELD_KEYS:+ }$key"
  done
}

play_cleanup() {
  local key
  if [ -n "${PLAY_XFD:-}" ]; then
    for key in $HELD_KEYS; do
      echo "keyup $key" >&"$PLAY_XFD"
    done
    exec {PLAY_XFD}>&-
    PLAY_XFD=""
  fi
  [ -z "${PLAY_FD:-}" ] || exec {PLAY_FD}<&-
  PLAY_FD=""
  [ -z "${PLAY_XPID:-}" ] || wait "$PLAY_XPID" 2>/dev/null || true
  PLAY_XPID=""
  HELD_KEYS=""
  rm -f "$STATE/play.fifo" "$STATE/play.ready"
}

play_until() {
  local pattern="$1" line seen=0 lines=0
  while :; do
    play_line || die "play: the game never logged '$pattern'"
    lines=$((lines + 1))
    [ "$lines" -lt 400 ] || die "play: the game never logged '$pattern'"
    [[ "$line" == *"$pattern"* ]] && seen=1
    if [ "$seen" = 1 ] && [[ "$line" =~ ^Step\ ([0-9]+): ]]; then
      PLAY_BASE="${BASH_REMATCH[1]}"
      return 0
    fi
  done
}

play_menu_press() {
  play_set "$1"
  PLAY_BASE=$((PLAY_BASE + 1))
  play_await "$PLAY_BASE"
}

cmd_play() {
  [ $# -eq 1 ] || die "usage: drive.sh play <script.inputs>"
  need xdotool python3
  local file steps players count keys frames=0 i
  file="$1"
  [ -f "$file" ] || die "no input script at '$file'"
  steps="$(parse_inputs "$file")" || exit 2
  [ -n "$steps" ] || die "$file has no frames"
  players="$(awk '{ sub(/#.*/, "") } $1 == "players" { print $2 }' "$file")"
  players="${players:-1}"
  game_running || die "game is not running, run: drive.sh start"
  [ -f "$STATE/game.log" ] || die "no game log at $STATE/game.log"
  rm -f "$STATE/play.fifo"
  mkfifo "$STATE/play.fifo"
  install_cleanup play_cleanup
  exec {PLAY_FD}<"$STATE/game.log"
  PLAY_PENDING=""
  while IFS= read -r -u "$PLAY_FD" _; do :; done
  rm -f "$STATE/play.ready"
  python3 -I "$LIVE/keypipe.py" "$STATE/play.ready" <"$STATE/play.fifo" &
  PLAY_XPID=$!
  exec {PLAY_XFD}>"$STATE/play.fifo"
  for i in $(seq 1 100); do
    [ -e "$STATE/play.ready" ] && break
    sleep 0.1
  done
  [ -e "$STATE/play.ready" ] || die "play: the key sender did not start"
  HELD_KEYS=""
  PLAY_LATE=0
  play_await 0
  PLAY_LATE=0
  PLAY_BASE="$PLAY_STEP"
  for ((i = 1; i < players; i++)); do
    play_set Up
    sleep 0.15
    play_set ""
    sleep 0.3
  done
  play_set z
  play_until "Starting Game"
  play_set ""
  sleep 0.5
  play_set z
  play_until "Loaded level"
  while read -r count keys; do
    [ "$keys" != - ] || keys=""
    for ((i = 0; i < count; i++)); do
      play_menu_press "$keys"
      frames=$((frames + 1))
    done
  done <<<"$steps"
  play_set ""
  play_cleanup
  restore_traps
  echo "play: $frames frames, $PLAY_LATE late"
  [ "$PLAY_LATE" = 0 ]
}

cmd_shot() {
  [ $# -eq 1 ] || die "usage: drive.sh shot <path>"
  need import
  display_up || die "no display $DISPLAY, run: drive.sh start"
  mkdir -p "$(dirname "$1")"
  import -window root "$1"
}

REC_BG=""

stop_record() {
  local last="${!:-}" job
  stop_proc "$STATE/record.pid" INT || true
  [ -n "$last" ] && [ "$last" != "$REC_BG" ] || return 0
  for job in $(jobs -p); do
    [ "$job" = "$last" ] || continue
    record_pid "$STATE/record.pid" "$job"
    stop_proc "$STATE/record.pid" INT || true
  done
}

cmd_record() {
  [ $# -eq 2 ] || die "usage: drive.sh record <seconds> <path>"
  local REC_LOCK_FD
  need ffmpeg flock
  display_up || die "no display $DISPLAY, run: drive.sh start"
  mkdir -p "$(dirname "$2")" "$STATE"
  exec {REC_LOCK_FD}>"$STATE/record.lock"
  flock -n "$REC_LOCK_FD" || die "a recording already runs on lane $LANE, run drive.sh stop first"
  ! pid_alive "$STATE/record.pid" || die "a recording already runs on lane $LANE (pid $(pid_of "$STATE/record.pid")), run drive.sh stop first"
  local rc=0
  REC_BG="${!:-}"
  install_cleanup stop_record
  ffmpeg -nostdin -loglevel error -y -f x11grab -draw_mouse 0 -framerate 30 -video_size "${SCREEN%x*}" -i "$DISPLAY" \
    -t "$1" -c:v libx264 -pix_fmt yuv420p "$2" &
  record_pid "$STATE/record.pid" $!
  wait $! || rc=$?
  stop_record
  restore_traps
  exec {REC_LOCK_FD}>&-
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
    play) cmd_play "$@" ;;
    shot) cmd_shot "$@" ;;
    record) cmd_record "$@" ;;
    stop) cmd_stop "$@" ;;
    smoke) cmd_smoke "$@" ;;
    golden) cmd_golden "$@" ;;
    *)
      echo "usage: drive.sh start [--level <n>] [--score <n>] | keys <script> | play <script.inputs> | shot <path> | record <seconds> <path> | stop | smoke | golden <path>" >&2
      exit 2
      ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  main "$@"
fi
