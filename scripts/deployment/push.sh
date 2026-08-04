#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/common.sh"
deployment_script_setup "push"

BUMP=false
DRY=false
MERGE_TARGETS=()
FILTERED_ARGS=()
while [[ $# -gt 0 ]]; do
	case "${1:-}" in
	--bump)
		BUMP=true
		shift
		;;
	--dry)
		DRY=true
		shift
		;;
	--merge-into)
		if [[ $# -lt 2 || -z "${2:-}" || "$2" == -* ]]; then
			echo -e "${RED}Error: ${WHITE}--merge-into${RED} requires a branch name!${RESET}" >&2
			exit 1
		fi
		if ! git check-ref-format --branch "$2" >/dev/null 2>&1; then
			echo -e "${RED}Error: ${WHITE}$2${RED} is not a valid branch name!${RESET}" >&2
			exit 1
		fi
		MERGE_TARGETS+=("$2")
		shift 2
		;;
	*)
		FILTERED_ARGS+=("$1")
		shift
		;;
	esac
done
parse_git_args "${FILTERED_ARGS[@]+"${FILTERED_ARGS[@]}"}"
require_repos_on_same_branch

if [[ "$BUMP" == "true" && "$ONLY_CORE" == "true" ]]; then
	echo -e "${RED}Error: Cannot use ${WHITE}--bump${RED} together with ${WHITE}--only-core${RESET}" >&2
	exit 1
fi

print_dry() {
	echo -e "${GRAY}[dry] $*${RESET}"
}

run_or_print() {
	if [[ "$DRY" == "true" ]]; then
		print_dry "$*"
		return 0
	fi
	"$@"
}

MERGE_TARGET_COUNT=${#MERGE_TARGETS[@]}
SOURCE_BRANCH=""
MERGE_BASE_CORE=()
MERGE_OLD_CORE=()
MERGE_BASE_CONFIG=()
MERGE_OLD_CONFIG=()

if [[ $MERGE_TARGET_COUNT -eq 0 && "$DRY" == "true" ]]; then
	echo -e "${RED}Error: ${WHITE}--dry${RED} requires ${WHITE}--merge-into${RED}!${RESET}" >&2
	exit 1
fi

if [[ $MERGE_TARGET_COUNT -gt 0 ]]; then
	if [[ "$BUMP" != "true" ]]; then
		echo -e "${RED}Error: ${WHITE}--merge-into${RED} requires ${WHITE}--bump${RED}!${RESET}" >&2
		exit 1
	fi

	if [[ "$DRY" == "true" ]]; then
		echo -e "${YELLOW}Dry run: merges and bumps run in temporary worktrees, nothing is pushed and no local branch is moved!${RESET}"
		echo
	fi

	if ! is_git_repo_dir "$CONFIG_DIR"; then
		echo -e "${RED}Error: Config directory is not a git repository, cannot use ${WHITE}--merge-into${RED}!${RESET}" >&2
		exit 1
	fi

	source_repo="$NXCORE_DIR"
	[[ "$ONLY_CONFIG" == true ]] && source_repo="$CONFIG_DIR"
	SOURCE_BRANCH="$(git -C "$source_repo" branch --show-current)"
	if [[ -z "$SOURCE_BRANCH" ]]; then
		echo -e "${RED}Error: Cannot use ${WHITE}--merge-into${RED} with a detached HEAD!${RESET}" >&2
		exit 1
	fi
	if [[ "$SOURCE_BRANCH" != "main" ]]; then
		echo -e "${RED}Error: ${WHITE}--merge-into${RED} is only allowed on the ${WHITE}main${RED} branch, but ${WHITE}$SOURCE_BRANCH${RED} is checked out!${RESET}" >&2
		exit 1
	fi

	index=0
	while [[ $index -lt $MERGE_TARGET_COUNT ]]; do
		target="${MERGE_TARGETS[$index]}"
		if [[ "$target" == "$SOURCE_BRANCH" ]]; then
			echo -e "${RED}Error: Cannot merge branch ${WHITE}$SOURCE_BRANCH${RED} into itself!${RESET}" >&2
			exit 1
		fi
		other=0
		while [[ $other -lt $index ]]; do
			if [[ "${MERGE_TARGETS[$other]}" == "$target" ]]; then
				echo -e "${RED}Error: Branch ${WHITE}$target${RED} was passed to ${WHITE}--merge-into${RED} more than once!${RESET}" >&2
				exit 1
			fi
			other=$((other + 1))
		done
		if [[ "$ONLY_CONFIG" != true ]] && is_branch_checked_out "$NXCORE_DIR" "$target"; then
			echo -e "${RED}Error: Branch ${WHITE}$target${RED} is checked out in a worktree of the core repository!${RESET}" >&2
			exit 1
		fi
		if is_branch_checked_out "$CONFIG_DIR" "$target"; then
			echo -e "${RED}Error: Branch ${WHITE}$target${RED} is checked out in a worktree of the config repository!${RESET}" >&2
			exit 1
		fi
		index=$((index + 1))
	done

	echo -e "${CYAN}Checking merge targets ${YELLOW}(Authentication required)${CYAN}...${RESET}"
	index=0
	while [[ $index -lt $MERGE_TARGET_COUNT ]]; do
		target="${MERGE_TARGETS[$index]}"
		base_ref=""
		old_ref=""
		if [[ "$ONLY_CONFIG" != true ]]; then
			base_ref="$(resolve_merge_target_base "$NXCORE_DIR" "core" "$target")" || exit 1
			old_ref="$(git -C "$NXCORE_DIR" rev-parse --verify --quiet "refs/heads/$target" || true)"
		fi
		MERGE_BASE_CORE+=("$base_ref")
		MERGE_OLD_CORE+=("$old_ref")

		base_ref="$(resolve_merge_target_base "$CONFIG_DIR" "config" "$target")" || exit 1
		old_ref="$(git -C "$CONFIG_DIR" rev-parse --verify --quiet "refs/heads/$target" || true)"
		MERGE_BASE_CONFIG+=("$base_ref")
		MERGE_OLD_CONFIG+=("$old_ref")
		index=$((index + 1))
	done
	echo
fi

cd "$NXCORE_DIR"
if [[ "$ONLY_CONFIG" != true ]]; then
	echo -e "${GREEN}Pushing core repository ${YELLOW}(Authentication required)${GREEN}...${RESET}"
	if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
		run_or_print git push "${EXTRA_ARGS[@]}"
	else
		run_or_print git push
	fi
fi

if [[ "$BUMP" == "true" ]]; then
	if [[ "$ONLY_CONFIG" != true ]] && [[ "$DRY" != "true" ]]; then
		echo
		echo -e "${CYAN}Waiting for remote to propagate...${RESET}"
		sleep 1
		echo
	fi
	echo -e "${CYAN}Pulling config repository before bump ${YELLOW}(Authentication required)${CYAN}...${RESET}"
	(cd "$CONFIG_DIR" && run_or_print git pull --no-rebase)
	echo
	echo -e "${CYAN}Bumping nxconfig to pushed nxcore...${RESET}"
	echo
	cd "$CONFIG_DIR"
	if [[ "$DRY" == "true" ]]; then
		print_dry "bump $CONFIG_DIR on $SOURCE_BRANCH, commit and push it"
	else
		run_bump "true" "true"
	fi
	echo
	if [[ "$DRY" == "true" ]]; then
		print_dry "Nothing was pushed for $SOURCE_BRANCH"
	elif [[ "$ONLY_CONFIG" == true ]]; then
		echo -e "${GREEN}Done. Config repository pushed successfully (with bump).${RESET}"
	else
		echo -e "${GREEN}Done. Both repositories pushed successfully (with bump).${RESET}"
	fi
elif [[ "$ONLY_CORE" != true ]] && is_git_repo_dir "$CONFIG_DIR"; then
	if [[ "$ONLY_CONFIG" != true ]]; then
		echo
	fi
	echo -e "${GREEN}Pushing config repository ${YELLOW}(Authentication required)${GREEN}...${RESET}"
	if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
		(cd "$CONFIG_DIR" && git push "${EXTRA_ARGS[@]}")
	else
		(cd "$CONFIG_DIR" && git push)
	fi
	if [[ "$ONLY_CONFIG" == true ]]; then
		echo
		echo -e "${GREEN}Config repository pushed successfully.${RESET}"
	else
		echo
		echo -e "${GREEN}Both repositories pushed successfully.${RESET}"
	fi
elif [[ "$ONLY_CORE" != true ]] && [[ "$ONLY_CONFIG" != true ]]; then
	echo
	echo -e "${YELLOW}Warning: Config directory is not a git repository, skipping push.${RESET}"
elif [[ "$ONLY_CORE" == true ]]; then
	echo
	echo -e "${GREEN}Core repository pushed successfully.${RESET}"
fi

[[ $MERGE_TARGET_COUNT -eq 0 ]] && exit 0

CORE_PUSHED_TARGET=""
PENDING_TARGET_INDEX=0

report_incomplete_merge_targets() {
	if [[ -n "$CORE_PUSHED_TARGET" ]]; then
		echo >&2
		echo -e "${RED}Error: The core branch ${WHITE}$CORE_PUSHED_TARGET${RED} was already pushed, but its config bump did not complete!${RESET}" >&2
		echo -e "${YELLOW}Re-run ${WHITE}nx push --bump --merge-into $CORE_PUSHED_TARGET${YELLOW} to finish it!${RESET}" >&2
	fi

	local pending=()
	local pending_index=$PENDING_TARGET_INDEX
	while [[ $pending_index -lt $MERGE_TARGET_COUNT ]]; do
		pending+=("${MERGE_TARGETS[$pending_index]}")
		pending_index=$((pending_index + 1))
	done

	if [[ ${#pending[@]} -gt 0 ]]; then
		echo >&2
		echo -e "${YELLOW}The following merge targets were not completed:${RESET}" >&2
		printf "  ${WHITE}%s${RESET}\n" "${pending[@]}" >&2
	fi
}

append_trap "cleanup_temp_worktrees" EXIT
append_trap "report_incomplete_merge_targets" EXIT

index=0
while [[ $index -lt $MERGE_TARGET_COUNT ]]; do
	target="${MERGE_TARGETS[$index]}"

	echo
	echo -e "${CYAN}Merging ${WHITE}$SOURCE_BRANCH${CYAN} into ${WHITE}$target${CYAN} and bumping it...${RESET}"
	echo

	NX_TEMP_WORKTREE_ROOT="$(mktemp_dir)"
	worktree_core="$NX_TEMP_WORKTREE_ROOT/core"
	worktree_config="$NX_TEMP_WORKTREE_ROOT/config"

	if [[ "$ONLY_CONFIG" != true ]]; then
		add_temp_worktree "$NXCORE_DIR" "$worktree_core" "${MERGE_BASE_CORE[$index]}"
		if ! merge_branch_in_dir "$worktree_core" "core" "$target worktree" "$SOURCE_BRANCH" "true" "Merge branch '$SOURCE_BRANCH' into $target"; then
			echo
			echo -e "${RED}Error: Merging ${WHITE}$SOURCE_BRANCH${RED} into ${WHITE}$target${RED} failed in the core repository, nothing was pushed for this branch!${RESET}" >&2
			echo -e "${YELLOW}The temporary worktree is discarded, resolve the conflicts in a checkout of ${WHITE}$target${YELLOW} and retry!${RESET}" >&2
			exit 1
		fi
		echo
	fi

	add_temp_worktree "$CONFIG_DIR" "$worktree_config" "${MERGE_BASE_CONFIG[$index]}"
	if ! merge_branch_in_dir "$worktree_config" "config" "$target worktree" "$SOURCE_BRANCH" "true" "Merge branch '$SOURCE_BRANCH' into $target"; then
		echo
		echo -e "${RED}Error: Merging ${WHITE}$SOURCE_BRANCH${RED} into ${WHITE}$target${RED} failed in the config repository, nothing was pushed for this branch!${RESET}" >&2
		echo -e "${YELLOW}The temporary worktree is discarded, resolve the conflicts in a checkout of ${WHITE}$target${YELLOW} and retry!${RESET}" >&2
		exit 1
	fi
	echo

	if [[ "$ONLY_CONFIG" != true ]]; then
		echo -e "${GREEN}Pushing core branch ${WHITE}$target${GREEN} ${YELLOW}(Authentication required)${GREEN}...${RESET}"
		run_or_print git -C "$worktree_core" push origin "HEAD:refs/heads/$target"
		merged_ref="$(git -C "$worktree_core" rev-parse HEAD)"
		run_or_print git -C "$NXCORE_DIR" update-ref "refs/heads/$target" "$merged_ref" "${MERGE_OLD_CORE[$index]}"
		if [[ "$DRY" != "true" ]]; then
			CORE_PUSHED_TARGET="$target"
			echo
			echo -e "${CYAN}Waiting for remote to propagate...${RESET}"
			sleep 1
		fi
		echo
	fi

	echo -e "${CYAN}Bumping nxconfig on branch ${WHITE}$target${CYAN}...${RESET}"
	echo
	(
		CONFIG_DIR="$worktree_config"
		if [[ "$ONLY_CONFIG" != true ]]; then
			NXCORE_DIR="$worktree_core"
		fi
		# shellcheck disable=SC2034
		NX_BUMP_BRANCH="$target"
		cd "$worktree_config"
		run_bump "true" "false"
	)

	echo -e "${GREEN}Pushing config branch ${WHITE}$target${GREEN} ${YELLOW}(Authentication required)${GREEN}...${RESET}"
	run_or_print git -C "$worktree_config" push origin "HEAD:refs/heads/$target"
	merged_ref="$(git -C "$worktree_config" rev-parse HEAD)"
	run_or_print git -C "$CONFIG_DIR" update-ref "refs/heads/$target" "$merged_ref" "${MERGE_OLD_CONFIG[$index]}"
	CORE_PUSHED_TARGET=""

	if [[ "$DRY" == "true" ]]; then
		echo
		if [[ "$ONLY_CONFIG" != true ]]; then
			print_dry "core ${target} would become $(git -C "$worktree_core" rev-parse --short HEAD)"
			git -C "$worktree_core" --no-pager diff --no-ext-diff --stat "${MERGE_BASE_CORE[$index]}" HEAD
		fi
		print_dry "config ${target} would become $(git -C "$worktree_config" rev-parse --short HEAD)"
		git -C "$worktree_config" --no-pager diff --no-ext-diff --stat "${MERGE_BASE_CONFIG[$index]}" HEAD
	fi

	cleanup_temp_worktrees

	echo
	if [[ "$DRY" == "true" ]]; then
		echo -e "${GREEN}Branch ${WHITE}$target${GREEN} merged and bumped successfully in the dry run, nothing was pushed.${RESET}"
	else
		echo -e "${GREEN}Branch ${WHITE}$target${GREEN} merged, bumped and pushed successfully.${RESET}"
	fi
	index=$((index + 1))
	PENDING_TARGET_INDEX=$index
done
