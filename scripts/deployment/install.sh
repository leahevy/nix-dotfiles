#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/common.sh"
simple_deployment_script_setup "install"

ensure_standalone_only "install"
check_deployment_conflicts "install"

if [[ "$(uname -s)" == "Darwin" ]]; then
	if ! command -v brew &>/dev/null; then
		echo -e "${RED}Homebrew not found in PATH${RESET}" >&2
		echo -e "${YELLOW}You can install it by running: ${WHITE}~/.local/bin-nx/brew-install${RESET}" >&2
		exit 1
	fi

	echo -e "${GREEN}Running Homebrew sync...${RESET}"

	if brew-sync; then
		notify_success "Install"
	else
		notify_error "Install"
		echo
		echo -e "${RED}Brew sync failed!${RESET}" >&2
		exit 1
	fi
else
	if command -v apt-get &>/dev/null; then
		if ! command -v apt-sync &>/dev/null; then
			echo -e "${RED}apt-sync not found in PATH${RESET}" >&2
			echo -e "${YELLOW}Run ${WHITE}nx sync${YELLOW} first to deploy the apt-sync script.${RESET}" >&2
			exit 1
		fi

		echo -e "${GREEN}Running apt sync...${RESET}"

		if apt-sync; then
			if command -v install-hooks &>/dev/null; then
				echo
				if ! install-hooks; then
					notify_error "Install"
					echo
					echo -e "${RED}Post-install hooks failed!${RESET}" >&2
					exit 1
				fi
			fi
			notify_success "Install"
		else
			notify_error "Install"
			echo
			echo -e "${RED}Apt sync failed!${RESET}" >&2
			exit 1
		fi
	else
		echo -e "${RED}No supported package manager found on this system${RESET}" >&2
		exit 1
	fi
fi
