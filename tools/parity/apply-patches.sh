#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2020-2026 ntwyman
# Usage: apply-patches.sh <source> <output> <patch>...
# Copies an upstream source file and applies the parity patches to the copy.
# Fuzz 0 makes a patch fail rather than land on drifted context.
set -euo pipefail
src="$1" out="$2"
shift 2
tmp="$out.tmp"
trap 'rm -f "$tmp" "$tmp.rej"' EXIT
cp "$src" "$tmp"
for p in "$@"; do
  patch --fuzz=0 --forward --batch --no-backup-if-mismatch "$tmp" "$p"
done
mv "$tmp" "$out"
