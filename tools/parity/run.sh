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
  echo "usage: run.sh --all | --script <name>" >&2
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

listed() {
  sed -e 's/#.*//' -e 's/[[:space:]]*$//' "$EXPECTED" | grep -qxF -- "$1"
}

# Compares two traces field by field. The first line it prints is PASS or
# 'DIVERGES at frame <n> field <name>'. Each later line names one field, the
# first frame it differs on, and both values, '-' meaning the field is absent.
compare() {
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

run_script() {
  local name="$1" script="$PARITY/scripts/$1.inputs"
  [ -f "$script" ] || { echo "run.sh: no script $script" >&2; exit 2; }
  mkdir -p "$TRACES"
  local side
  for side in port original; do
    if ! "$BUILD/parity-$side" "$script" >"$TRACES/$name.$side" 2>"$TRACES/$name.$side.log"; then
      cat "$TRACES/$name.$side.log" >&2
      echo "run.sh: the $side driver failed on $name" >&2
      exit 2
    fi
  done
  compare "$TRACES/$name.port" "$TRACES/$name.original"
}

# Prints the result line for one script and returns 1 when the result does
# not match expected-divergent.txt.
check() {
  local name="$1" result="$2"
  if [ "$result" = PASS ] && listed "$name"; then
    echo "run.sh: $name passes but is listed in expected-divergent.txt; remove it" >&2
    return 1
  fi
  if [ "$result" != PASS ] && ! listed "$name"; then
    echo "run.sh: $name diverges but is not listed in expected-divergent.txt" >&2
    return 1
  fi
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
        out="$(run_script "$name")"
        echo "$name ${out%%$'\n'*}"
        check "$name" "${out%%$'\n'*}" || status=1
      done
      while read -r name; do
        [ -f "$PARITY/scripts/$name.inputs" ] || {
          echo "run.sh: expected-divergent.txt lists $name, which has no script" >&2
          status=1
        }
      done < <(sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$EXPECTED")
      ;;
    --script)
      [ $# -eq 2 ] || usage
      build
      out="$(run_script "$2")"
      echo "$2 $out"
      check "$2" "${out%%$'\n'*}" || status=1
      ;;
    *) usage ;;
  esac
  return "$status"
}

main "$@"
