#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

export TE_PACKAGES_OUT="$workdir/highlight-packages.txt"
: >"$TE_PACKAGES_OUT"

status=0
"$SCRIPT_DIR/run-all-test-evals.sh" "$@" || status=$?

echo ""
echo "Collected packages:"
sort -fu "$TE_PACKAGES_OUT"

exit "$status"
