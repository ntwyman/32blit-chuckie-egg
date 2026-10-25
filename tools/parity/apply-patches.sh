#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2020-2026 ntwyman
# Usage: apply-patches.sh <source> <output> <patch>...
# Copies an upstream source file and applies the parity patches to the copy.
set -euo pipefail
src="$1" out="$2"
shift 2
tmp="$out.tmp"
cp "$src" "$tmp"
for p in "$@"; do
  patch --quiet --forward --no-backup-if-mismatch "$tmp" "$p"
done
mv "$tmp" "$out"
