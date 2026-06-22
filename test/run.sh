#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob   # no *_test.sh yet => empty loop, not a literal-glob failure
cd "$(dirname "$0")"
rc=0
for t in *_test.sh; do
  echo "== $t =="
  bash "$t" || rc=1
done
exit $rc
