#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2020-2026 ntwyman
set -euo pipefail
export LC_ALL=C

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PARITY="$ROOT/tools/parity"
BUILD="${PARITY_BUILD:-$ROOT/build.parity}"
EXPECTED="$PARITY/expected-divergent.txt"
TRACES="$BUILD/parity/traces"

usage() {
  echo "usage: run.sh --all | --script <name> | --record <name> | --clock | --game-over | --sound | --high-scores | --title | --self-test" >&2
  exit 2
}

build() {
  local log="$BUILD/parity-build.log" args
  read -ra args <<<"${PARITY_CMAKE_ARGS:-}"
  mkdir -p "$BUILD"
  if ! { cmake -B "$BUILD" -S "$ROOT" -DCHUCKIE_PARITY=ON -DCMAKE_BUILD_TYPE=Release "${args[@]}" &&
    cmake --build "$BUILD" --target parity -j4; } >"$log" 2>&1; then
    cat "$log" >&2
    echo "run.sh: the parity build failed, see $log" >&2
    exit 2
  fi
}

names() {
  sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$1"
}

listed() {
  names "$EXPECTED" | grep -qxF -- "$1"
}

pinned() {
  echo "$PARITY/$1-divergences.txt"
}

compare() {
  [ -s "$1" ] && [ -s "$2" ] || {
    echo "run.sh: a trace is empty: $1 $2" >&2
    exit 2
  }
  local diffs report
  diffs="$(mktemp)"
  report="$(awk -v port="$1" -v orig="$2" -v diffs="$diffs" '
    function load(line, names, values, order,    n, i, kv) {
      n = split(line, kv, " ")
      for (i = 1; i <= n; i++) {
        split(kv[i], parts, "=")
        names[parts[1]] = 1
        values[parts[1]] = parts[2]
        order[i] = parts[1]
      }
      return n
    }
    BEGIN {
      frame = 0
      while (1) {
        p_ok = (getline pl < port) > 0
        o_ok = (getline ol < orig) > 0
        if (!p_ok && !o_ok) break
        if (!p_ok) pl = ""
        if (!o_ok) ol = ""
        delete pn; delete pv; delete po; delete on; delete ov; delete oo
        np = load(pl, pn, pv, po)
        no = load(ol, on, ov, oo)
        for (i = 1; i <= no + np; i++) {
          f = i <= no ? oo[i] : po[i - no]
          if (i > no && (f in on)) continue
          a = (f in pn) ? pv[f] : "-"
          b = (f in on) ? ov[f] : "-"
          if (a != b) {
            print frame, f, a, b >diffs
            if (!(f in first)) {
              first[f] = frame
              fields[++nf] = f
              pval[f] = a
              oval[f] = b
            }
          }
        }
        frame++
      }
      if (nf == 0) { print "PASS"; exit }
      print "DIVERGES at frame " first[fields[1]] " field " fields[1]
      for (i = 1; i <= nf; i++) {
        f = fields[i]
        print "  " f " first differs at frame " first[f] ": port " pval[f] ", original " oval[f]
      }
    }')"
  echo "$report"
  if [ -s "$diffs" ]; then
    echo "  every difference: $(wc -l <"$diffs") field values over $(cut -d' ' -f1 "$diffs" | sort -u | wc -l) frames, sha256 $(sha256sum <"$diffs" | cut -c1-16)"
  fi
  rm -f "$diffs"
}

report() {
  local name="$1" script="$PARITY/scripts/$1.inputs" side
  [ -f "$script" ] || { echo "run.sh: no script $script" >&2; exit 2; }
  mkdir -p "$TRACES"
  for side in port original; do
    if ! "$BUILD/parity-$side" "$script" >"$TRACES/$name.$side" 2>"$TRACES/$name.$side.log"; then
      cat "$TRACES/$name.$side.log" >&2
      echo "run.sh: the $side driver failed on $name" >&2
      exit 2
    fi
  done
  local result
  result="$(compare "$TRACES/$name.port" "$TRACES/$name.original")"
  echo "$name $result"
}

check() {
  local name="$1" out="$2" file
  file="$(pinned "$name")"
  if [ "$out" = "$name PASS" ]; then
    if listed "$name"; then
      echo "run.sh: $name passes but is listed in expected-divergent.txt; remove it and $(basename "$file")" >&2
      return 1
    fi
    return 0
  fi
  if ! listed "$name"; then
    echo "run.sh: $name diverges but is not listed in expected-divergent.txt" >&2
    return 1
  fi
  if [ ! -f "$file" ]; then
    echo "run.sh: $name is listed but $(basename "$file") is missing; run run.sh --record $name" >&2
    return 1
  fi
  if ! diff -u <(grep -v '^#' "$file") <(echo "$out") >&2; then
    echo "run.sh: $name diverges differently from $(basename "$file") (diff above, - pinned, + now); if the change is intended, run run.sh --record $name" >&2
    return 1
  fi
}

check_files() {
  local status=0 file name
  for file in "$PARITY"/*-divergences.txt; do
    [ -e "$file" ] || continue
    name="$(basename "$file" -divergences.txt)"
    listed "$name" || {
      echo "run.sh: $(basename "$file") pins $name, which expected-divergent.txt does not list" >&2
      status=1
    }
  done
  while read -r name; do
    [ -f "$PARITY/scripts/$name.inputs" ] || {
      echo "run.sh: expected-divergent.txt lists $name, which has no script" >&2
      status=1
    }
  done < <(names "$EXPECTED")
  return "$status"
}

record() {
  local name="$1" out
  listed "$name" || { echo "run.sh: list $name in expected-divergent.txt before recording it" >&2; exit 2; }
  out="$(report "$name")"
  {
    echo "# What \`tools/parity/run.sh --script $name\` reports. run.sh fails when the report changes."
    echo "# Each indented line is a field, the first frame it differs on, and both values. The last line counts and hashes every difference."
    echo "# Rewrite it with \`run.sh --record $name\` only for a change the PR means to make."
    echo "$out"
  } >"$(pinned "$name")"
  echo "run.sh: wrote $(pinned "$name")"
}

# The title adds states in front of the player-count screen, so a trace must not change when the port driver
# starts there. This runs the port on every script with --start-at-title and compares it with the same run
# that skips the title, and checks that the idle script still passes against the original.
title_check() {
  local script name status=0
  mkdir -p "$TRACES"
  for script in "$PARITY"/scripts/*.inputs; do
    name="$(basename "$script" .inputs)"
    "$BUILD/parity-port" --start-at-title "$script" >"$TRACES/$name.title" 2>/dev/null || {
      echo "run.sh: the port driver failed on $name with --start-at-title" >&2
      return 2
    }
    "$BUILD/parity-port" "$script" >"$TRACES/$name.notitle" 2>/dev/null
    if ! cmp -s "$TRACES/$name.title" "$TRACES/$name.notitle"; then
      echo "run.sh: $name differs when the title is skipped by --start-at-title" >&2
      status=1
    fi
  done
  local out
  out="$(compare "$TRACES/idle.title" "$TRACES/idle.original")"
  [ "${out%%$'\n'*}" = PASS ] || {
    echo "run.sh: idle does not pass after the title is skipped: ${out%%$'\n'*}" >&2
    status=1
  }
  [ "$status" = 0 ] && echo "title: ok"
  return "$status"
}

self_test() {
  local d status=0 got
  d="$(mktemp -d)"
  printf 'frame=0 a=1 b=2\nframe=1 a=1 b=2\n' >"$d/base"
  cp "$d/base" "$d/same"
  printf 'frame=0 a=1 b=2\nframe=1 a=1 b=3\n' >"$d/value"
  printf 'frame=0 a=1 b=2\n' >"$d/short"
  printf 'frame=0 a=1 b=2\nframe=1 abort=1\n' >"$d/abort"
  printf 'frame=0 a=1 b=2 c=4\nframe=1 a=1 b=2 c=4\n' >"$d/extra"
  printf 'frame=0 a=1 b=2\nframe=1 a=1 b=3\nframe=2 a=1 b=3\n' >"$d/late3"
  printf 'frame=0 a=1 b=2\nframe=1 a=1 b=3\nframe=2 a=1 b=9\n' >"$d/late9"
  printf 'frame=0 a=1 b=2\nframe=1 a=1 b=2\nframe=2 a=1 b=2\n' >"$d/flat"
  : >"$d/empty"
  expect() {
    if [ "$got" != "$1" ]; then
      echo "self-test: $2: expected '$1', got '$got'" >&2
      status=1
    fi
  }
  got="$(compare "$d/same" "$d/base")"
  expect "PASS" "identical traces"
  got="$(compare "$d/value" "$d/base" | head -1)"
  expect "DIVERGES at frame 1 field b" "one value"
  got="$(compare "$d/short" "$d/base" | head -1)"
  expect "DIVERGES at frame 1 field frame" "port one frame short"
  got="$(compare "$d/base" "$d/abort" | head -1)"
  expect "DIVERGES at frame 1 field abort" "original aborts"
  got="$(compare "$d/extra" "$d/base" | head -1)"
  expect "DIVERGES at frame 0 field c" "a field only the port has"
  got="$(compare "$d/late3" "$d/flat" | head -2 | tail -1)"
  expect "  b first differs at frame 1: port 3, original 2" "first difference line"
  got="$(compare "$d/late3" "$d/flat" | tail -1 | cut -d, -f1)"
  expect "  every difference: 2 field values over 2 frames" "difference count"
  got="$([ "$(compare "$d/late3" "$d/flat" | tail -1)" != "$(compare "$d/late9" "$d/flat" | tail -1)" ] && echo differ || echo same)"
  expect "differ" "a field changing only after its first divergence"
  got="$([ "$(compare "$d/late3" "$d/flat")" = "$(compare "$d/late3" "$d/flat")" ] && echo same || echo differ)"
  expect "same" "the same traces report the same"
  got="$( (compare "$d/empty" "$d/empty") 2>/dev/null)" || got="refused"
  expect "refused" "empty traces"
  rm -rf "$d"
  [ "$status" = 0 ] && echo "self-test: ok"
  return "$status"
}

main() {
  [ $# -ge 1 ] || usage
  local status=0 name out
  case "$1" in
    --all)
      [ $# -eq 1 ] || usage
      build
      for script in "$PARITY"/scripts/*.inputs; do
        name="$(basename "$script" .inputs)"
        out="$(report "$name")"
        echo "${out%%$'\n'*}"
        check "$name" "$out" || status=1
      done
      check_files || status=1
      "$BUILD/parity-clock" || status=1
      "$BUILD/parity-gameover" || status=1
      "$BUILD/parity-sound" || status=1
      "$BUILD/parity-highscores" || status=1
      title_check || status=1
      ;;
    --script)
      [ $# -eq 2 ] || usage
      build
      out="$(report "$2")"
      echo "$out"
      check "$2" "$out" || status=1
      ;;
    --record)
      [ $# -eq 2 ] || usage
      build
      record "$2"
      ;;
    --clock)
      [ $# -eq 1 ] || usage
      build
      "$BUILD/parity-clock" || status=1
      ;;
    --game-over)
      [ $# -eq 1 ] || usage
      build
      "$BUILD/parity-gameover" || status=1
      ;;
    --sound)
      [ $# -eq 1 ] || usage
      build
      "$BUILD/parity-sound" || status=1
      ;;
    --high-scores)
      [ $# -eq 1 ] || usage
      build
      "$BUILD/parity-highscores" || status=1
      ;;
    --title)
      [ $# -eq 1 ] || usage
      build
      title_check || status=1
      ;;
    --self-test)
      [ $# -eq 1 ] || usage
      self_test || status=1
      ;;
    *) usage ;;
  esac
  return "$status"
}

main "$@"
