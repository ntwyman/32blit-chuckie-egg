#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

status=0

list=$(mktemp)
trap 'rm -f "$list"' EXIT

git ls-files -z -- '*.cpp' '*.hpp' ':!:third_party/**' > "$list"

if [[ ! -s "$list" ]]; then
  echo "no tracked .cpp or .hpp files found; the git listing failed" >&2
  exit 1
fi

while IFS= read -r -d '' file; do
  if ! grep -qF -- 'SPDX-License-Identifier: GPL-3.0-only' "$file"; then
    echo "missing SPDX line: $file" >&2
    status=1
  fi
done < "$list"

if ! cmp -s LICENSE third_party/pbrook-chuckie-egg/COPYING; then
  echo "LICENSE differs from third_party/pbrook-chuckie-egg/COPYING" >&2
  status=1
fi

exit "$status"
