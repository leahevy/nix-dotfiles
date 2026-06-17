#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/common.sh"
deployment_script_setup "check"

NEXT_RELEASE=false

while [[ $# -gt 0 ]]; do
	case "${1:-}" in
	--next-release)
		NEXT_RELEASE=true
		shift
		;;
	-*)
		echo -e "${RED}Unknown option ${WHITE}${1:-}${RESET}" >&2
		exit 1
		;;
	*)
		echo -e "${RED}Unknown argument ${WHITE}${1:-}${RESET}" >&2
		exit 1
		;;
	esac
done

HYDRA_CHECK_CURRENT="$HOME/.local/bin-nx/hydra-check-current-release"
HYDRA_CHECK_NEXT="$HOME/.local/bin-nx/hydra-check-next-release"

if [[ "$NEXT_RELEASE" == "true" ]]; then
	if [[ ! -x "$HYDRA_CHECK_NEXT" ]]; then
		echo -e "${RED}Error: ${WHITE}$HYDRA_CHECK_NEXT${RED} not found!${RESET}" >&2
		echo -e "${YELLOW}Make sure the build/core/packages module is enabled.${RESET}" >&2
		exit 1
	fi
	exec "$HYDRA_CHECK_NEXT"
else
	if [[ ! -x "$HYDRA_CHECK_CURRENT" ]]; then
		echo -e "${RED}Error: ${WHITE}$HYDRA_CHECK_CURRENT${RED} not found!${RESET}" >&2
		echo -e "${YELLOW}Make sure the build/core/packages module is enabled.${RESET}" >&2
		exit 1
	fi
	exec "$HYDRA_CHECK_CURRENT"
fi
