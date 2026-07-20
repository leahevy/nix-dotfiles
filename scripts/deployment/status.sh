#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/common.sh"
deployment_script_setup "status"
parse_git_args "$@"

if [[ "$ONLY_CONFIG" != true ]]; then
	cd "$NXCORE_DIR"
	CORE_BRANCH="$(git branch --show-current)"
	CORE_BRANCH_SUFFIX=""
	[[ -n "$CORE_BRANCH" && "$CORE_BRANCH" != "main" ]] && CORE_BRANCH_SUFFIX=" ${YELLOW}(${CORE_BRANCH})${RESET}"
	echo -e "${GREEN}Status of core repository ${WHITE}(.config/nx/nxcore)${RESET}${CORE_BRANCH_SUFFIX}..."
	if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
		git status --porcelain "${EXTRA_ARGS[@]}"
	else
		git status --porcelain
	fi
fi

if [[ "$ONLY_CORE" != true ]] && [[ -d "$CONFIG_DIR/.git" ]]; then
	if [[ "$ONLY_CONFIG" != true ]]; then
		echo
	fi
	CONFIG_BRANCH="$(cd "$CONFIG_DIR" && git branch --show-current)"
	CONFIG_BRANCH_SUFFIX=""
	[[ -n "$CONFIG_BRANCH" && "$CONFIG_BRANCH" != "main" ]] && CONFIG_BRANCH_SUFFIX=" ${YELLOW}(${CONFIG_BRANCH})${RESET}"
	echo -e "${GREEN}Status of config repository ${WHITE}(.config/nx/nxconfig)${RESET}${CONFIG_BRANCH_SUFFIX}..."
	if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
		(cd "$CONFIG_DIR" && git status --porcelain "${EXTRA_ARGS[@]}")
	else
		(cd "$CONFIG_DIR" && git status --porcelain)
	fi
elif [[ "$ONLY_CORE" != true ]] && [[ "$ONLY_CONFIG" != true ]]; then
	echo
	echo -e "${YELLOW}Warning: Config directory does not exist or is no directory.${RESET}"
fi
