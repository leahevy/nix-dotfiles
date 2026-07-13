#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/common.sh"
deployment_script_setup "merge"
parse_git_args "$@"
cd "$NXCORE_DIR"

BRANCH_TO_MERGE=""
for arg in "${EXTRA_ARGS[@]}"; do
	if [[ "$arg" != --* && "$arg" != -* ]]; then
		if [[ -z "$BRANCH_TO_MERGE" ]]; then
			BRANCH_TO_MERGE="$arg"
		else
			echo -e "${RED}Error: Multiple branch names provided. Please provide only one branch name to merge.${RESET}"
			exit 1
		fi
	fi
done
if [[ -z "$BRANCH_TO_MERGE" ]]; then
	echo -e "${RED}Error: No branch name provided. Please provide a branch name to merge.${RESET}"
	exit 1
fi

check_repo_merge_safety() {
	local repo_path="$1"
	local repo_name="$2"

	pushd "$repo_path" >/dev/null

	local current_branch
	current_branch=$(git branch --show-current)

	if [[ "$current_branch" == "$BRANCH_TO_MERGE" ]]; then
		echo -e "${RED}Error: Cannot merge branch '${BRANCH_TO_MERGE}' into itself in $repo_name repository.${RESET}"
		popd >/dev/null
		return 1
	fi

	if ! git show-ref --verify --quiet "refs/heads/$BRANCH_TO_MERGE"; then
		echo -e "${RED}Error: Branch '${BRANCH_TO_MERGE}' does not exist in $repo_name repository.${RESET}"
		popd >/dev/null
		return 1
	fi

	popd >/dev/null
	return 0
}

require_repos_on_same_branch

if [[ "$ONLY_CONFIG" != true ]]; then
	if ! check_repo_merge_safety "." "core"; then
		exit 1
	fi
fi

if [[ "$ONLY_CORE" != true ]] && [[ -d "$CONFIG_DIR/.git" ]]; then
	if ! check_repo_merge_safety "$CONFIG_DIR" "config"; then
		exit 1
	fi
fi

resolve_generated_conflicts() {
	local repo_name="$1"

	if [[ "$repo_name" != "config" ]]; then
		exit 1
	fi

	local conflicts=()
	local file
	while IFS= read -r file; do
		[[ -n "$file" ]] && conflicts+=("$file")
	done < <(git diff --name-only --diff-filter=U)

	if [[ ${#conflicts[@]} -eq 0 ]]; then
		exit 1
	fi

	local remaining=()
	for file in "${conflicts[@]}"; do
		case "$file" in
		.label | flake.lock | .core-state/*)
			echo -e "${CYAN}Auto-resolving ${WHITE}$file${CYAN} with the version from ${WHITE}$BRANCH_TO_MERGE${CYAN}...${RESET}"
			if git checkout --theirs -- "$file" 2>/dev/null; then
				git add -- "$file"
			else
				git rm --quiet -f -- "$file"
			fi
			;;
		*)
			remaining+=("$file")
			;;
		esac
	done

	if [[ ${#remaining[@]} -gt 0 ]]; then
		echo
		echo -e "${RED}Merge conflicts require manual resolution:${RESET}"
		printf "  ${WHITE}%s${RESET}\n" "${remaining[@]}"
		exit 1
	fi

	git commit --no-edit
}

merge_branch_in_repo() {
	local repo_path="$1"
	local repo_name="$2"
	local repo_label="$3"

	pushd "$repo_path" >/dev/null

	if git merge-base --is-ancestor HEAD "refs/heads/$BRANCH_TO_MERGE"; then
		echo -e "${GREEN}Fast-forwarding to branch ${WHITE}$BRANCH_TO_MERGE${GREEN} in $repo_name repository ${WHITE}($repo_label)${RESET}..."
		git merge --ff-only "$BRANCH_TO_MERGE"
	else
		echo -e "${GREEN}Merging branch ${WHITE}$BRANCH_TO_MERGE${GREEN} with a merge commit in $repo_name repository ${WHITE}($repo_label)${RESET}..."
		if ! git merge "$BRANCH_TO_MERGE"; then
			resolve_generated_conflicts "$repo_name"
		fi
	fi

	popd >/dev/null
}

if [[ "$ONLY_CONFIG" != true ]]; then
	merge_branch_in_repo "." "core" ".config/nx/nxcore"
fi

if [[ "$ONLY_CORE" != true ]] && [[ -d "$CONFIG_DIR/.git" ]]; then
	if [[ "$ONLY_CONFIG" != true ]]; then
		echo
	fi
	merge_branch_in_repo "$CONFIG_DIR" "config" ".config/nx/nxconfig"
elif [[ "$ONLY_CORE" != true ]] && [[ "$ONLY_CONFIG" != true ]]; then
	echo
	echo -e "${YELLOW}Warning: Config directory does not exist or is no directory.${RESET}"
fi
