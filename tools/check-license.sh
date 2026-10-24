#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

status=0

while IFS= read -r file; do
  if ! grep -q 'SPDX-License-Identifier: GPL-3.0-only' "$file"; then
    echo "missing SPDX line: $file" >&2
    status=1
  fi
done < <(find . \( -path ./third_party -o -path ./.git -o -path ./.claude -o -path './build*' \) -prune -o \
  -type f \( -name '*.cpp' -o -name '*.hpp' \) -print | sort)

if ! cmp -s LICENSE third_party/pbrook-chuckie-egg/COPYING; then
  echo "LICENSE differs from third_party/pbrook-chuckie-egg/COPYING" >&2
  status=1
fi

exit "$status"
