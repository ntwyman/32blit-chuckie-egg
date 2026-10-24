#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

status=0

while IFS= read -r -d '' file; do
  if ! grep -q 'SPDX-License-Identifier: GPL-3.0-only' "$file"; then
    echo "missing SPDX line: $file" >&2
    status=1
  fi
done < <(git ls-files -z -- '*.cpp' '*.hpp' ':!:third_party/**')

if ! cmp -s LICENSE third_party/pbrook-chuckie-egg/COPYING; then
  echo "LICENSE differs from third_party/pbrook-chuckie-egg/COPYING" >&2
  status=1
fi

exit "$status"
