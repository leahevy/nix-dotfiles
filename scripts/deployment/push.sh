#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/common.sh"
deployment_script_setup "push"

BUMP=false
FILTERED_ARGS=()
for arg in "$@"; do
	if [[ "$arg" == "--bump" ]]; then
		BUMP=true
	else
		FILTERED_ARGS+=("$arg")
	fi
done
parse_git_args "${FILTERED_ARGS[@]+"${FILTERED_ARGS[@]}"}"

if [[ "$BUMP" == "true" && "$ONLY_CORE" == "true" ]]; then
	echo -e "${RED}Error: Cannot use ${WHITE}--bump${RED} together with ${WHITE}--only-core${RESET}" >&2
	exit 1
fi

cd "$NXCORE_DIR"
if [[ "$ONLY_CONFIG" != true ]]; then
	echo -e "${GREEN}Pushing core repository ${YELLOW}(Authentication required)${GREEN}...${RESET}"
	if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
		git push "${EXTRA_ARGS[@]}"
	else
		git push
	fi
fi

if [[ "$BUMP" == "true" ]]; then
	if [[ "$ONLY_CONFIG" != true ]]; then
		echo
		echo -e "${CYAN}Waiting for remote to propagate...${RESET}"
		sleep 1
		echo
	fi
	echo -e "${CYAN}Pulling config repository before bump ${YELLOW}(Authentication required)${CYAN}...${RESET}"
	(cd "$CONFIG_DIR" && git pull)
	echo
	echo -e "${CYAN}Bumping nxconfig to pushed nxcore...${RESET}"
	echo
	cd "$CONFIG_DIR"
	run_bump "true" "true"
	echo
	if [[ "$ONLY_CONFIG" == true ]]; then
		echo -e "${GREEN}Done. Config repository pushed successfully (with bump).${RESET}"
	else
		echo -e "${GREEN}Done. Both repositories pushed successfully (with bump).${RESET}"
	fi
elif [[ "$ONLY_CORE" != true ]] && [[ -d "$CONFIG_DIR/.git" ]]; then
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
