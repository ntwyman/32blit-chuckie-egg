#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2020-2026 ntwyman
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PARITY="$ROOT/tools/parity"
BUILD="${PARITY_BUILD:-$ROOT/build.parity}"
EXPECTED="$PARITY/expected-divergent.txt"
TRACES="$BUILD/parity/traces"

usage() {
  echo "usage: run.sh --all | --script <name> | --record <name> | --self-test" >&2
  exit 2
}

build() {
  local log="$BUILD/parity-build.log"
  mkdir -p "$BUILD"
  # PARITY_CMAKE_ARGS is split on spaces on purpose, to pass several -D flags.
  # shellcheck disable=SC2086
  if ! { cmake -B "$BUILD" -S "$ROOT" -DCHUCKIE_PARITY=ON -DCMAKE_BUILD_TYPE=Release ${PARITY_CMAKE_ARGS:-} &&
    cmake --build "$BUILD" --target parity -j; } >"$log" 2>&1; then
    cat "$log" >&2
    echo "run.sh: the parity build failed, see $log" >&2
    exit 2
  fi
}

# Prints the names in a list file, without comments or blank lines.
names() {
  sed -e 's/#.*//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$1"
}

listed() {
  names "$EXPECTED" | grep -qxF -- "$1"
}

# Where a listed script's report is pinned.
pinned() {
  echo "$PARITY/$1-divergences.txt"
}

# Compares two traces field by field. The first line it prints is PASS or
# 'DIVERGES at frame <n> field <name>'. Each later line names one field, the
# first frame it differs on, and both values, '-' meaning the field is absent.
# Fields that first differ on the same frame keep the original's field order.
compare() {
  [ -s "$1" ] && [ -s "$2" ] || {
    echo "run.sh: a trace is empty: $1 $2" >&2
    exit 2
  }
  awk -v port="$1" -v orig="$2" '
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
          if (a != b && !(f in first)) {
            first[f] = frame
            fields[++nf] = f
            pval[f] = a
            oval[f] = b
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
    }'
}

# Runs both drivers on one script and prints its full report.
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

# Returns 1, with a reason on stderr, when a script's report does not match
# expected-divergent.txt and its pinned report.
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

# A pinned report with no listing, or a listing with no script, also fails.
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
    echo "# Each indented line is a field, the first frame it differs on, and both values."
    echo "# Rewrite it with \`run.sh --record $name\` only for a change the PR means to make."
    echo "$out"
  } >"$(pinned "$name")"
  echo "run.sh: wrote $(pinned "$name")"
}

# Checks compare on fixed traces, so a broken comparator cannot report PASS.
self_test() {
  local d status=0 got
  d="$(mktemp -d)"
  printf 'frame=0 a=1 b=2\nframe=1 a=1 b=2\n' >"$d/base"
  cp "$d/base" "$d/same"
  printf 'frame=0 a=1 b=2\nframe=1 a=1 b=3\n' >"$d/value"
  printf 'frame=0 a=1 b=2\n' >"$d/short"
  printf 'frame=0 a=1 b=2\nframe=1 abort=1\n' >"$d/abort"
  printf 'frame=0 a=1 b=2 c=4\nframe=1 a=1 b=2 c=4\n' >"$d/extra"
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
    --self-test)
      [ $# -eq 1 ] || usage
      self_test || status=1
      ;;
    *) usage ;;
  esac
  return "$status"
}

main "$@"
