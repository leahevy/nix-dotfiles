#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

source "$CORE_DIR/scripts/utils/defs.sh"

case_filter="${1:-}"

case_scripts=()
for case_script in "$SCRIPT_DIR"/test-evals.d/*.sh; do
	if [ -n "$case_filter" ]; then
		base="$(basename "$case_script")"
		name="${base%.sh}"
		name="${name#[0-9][0-9]-}"
		if [ "$base" != "$case_filter" ] && [ "${base%.sh}" != "$case_filter" ] && [ "$name" != "$case_filter" ]; then
			continue
		fi
	fi
	case_scripts+=("$case_script")
done

if [ "${#case_scripts[@]}" -eq 0 ]; then
	echo "No test case matches '$case_filter'. Available cases:" >&2
	for case_script in "$SCRIPT_DIR"/test-evals.d/*.sh; do
		base="$(basename "$case_script" .sh)"
		echo "  ${base#[0-9][0-9]-}" >&2
	done
	exit 1
fi

export TE_DUMMY_AGE_PUBLIC_KEY="age1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq"
export TE_FIXED_EVAL_TIMESTAMP="0"

TE_WORKROOT=$(mktemp -d)
trap 'rm -rf "$TE_WORKROOT"' EXIT

GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null git clone --depth 1 \
	"$TEST_EVAL_TEMPLATE_REPO_URL" "$TE_WORKROOT/template"
rm -rf "$TE_WORKROOT/template/.git"
cp -a "$CORE_DIR/.github/test-config/." "$TE_WORKROOT/template/"

grep -rl '@SOPS_AGE_PUBLIC_KEY@' "$TE_WORKROOT/template/profiles" | while IFS= read -r file; do
	sed -i "s/@SOPS_AGE_PUBLIC_KEY@/$TE_DUMMY_AGE_PUBLIC_KEY/g" "$file"
done

export TE_CORE_DIR="$CORE_DIR"
export TE_TEMPLATE_DIR="$TE_WORKROOT/template"
export TE_RESULTS_TSV="$TE_WORKROOT/results.tsv"
: >"$TE_RESULTS_TSV"

failed=0
for case_script in "${case_scripts[@]}"; do
	case_name="$(basename "$case_script" .sh)"
	case_name="${case_name#[0-9][0-9]-}"
	export TE_CASE_NAME="$case_name"
	echo "==> Test case: $case_name"
	if ! bash "$case_script"; then
		printf '%s\tFAILED\t-\n' "$case_name" >>"$TE_RESULTS_TSV"
		failed=1
	fi
	echo ""
done

total=0
ok=0
while IFS=$'\t' read -r _ status _; do
	total=$((total + 1))
	if [ "$status" = "OK" ]; then
		ok=$((ok + 1))
	fi
done <"$TE_RESULTS_TSV"

RESULTS_MD="${TEST_EVAL_RESULTS_MD:-$TE_WORKROOT/results.md}"
{
	echo '<!-- nx-eval-results-start -->'
	if [ "$failed" -eq 0 ]; then
		echo "**Test evaluations: $ok/$total profiles evaluated successfully.** [OK]"
	else
		echo '> [!CAUTION]'
		echo '> **Test Build Failed**'
		if [ "$ok" -eq 0 ]; then
			echo "> All $total test profiles failed to evaluate with the updated inputs!"
		else
			echo "> Only $ok/$total test profiles evaluated successfully with the updated inputs!"
		fi
		echo ''
		echo '| Test case | Result |'
		echo '| --- | --- |'
		while IFS=$'\t' read -r name status _; do
			echo "| $name | $status |"
		done <"$TE_RESULTS_TSV"
	fi
	echo '<!-- nx-eval-results-end -->'
} >"$RESULTS_MD"

echo "Evaluation summary ($ok/$total OK):"
while IFS=$'\t' read -r name status drv; do
	if [ "$status" = "OK" ]; then
		echo "  $name: OK $drv"
	else
		echo "  $name: FAILED"
	fi
done <"$TE_RESULTS_TSV"

exit "$failed"
