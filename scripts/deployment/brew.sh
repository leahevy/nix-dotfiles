#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/common.sh"
simple_deployment_script_setup "brew"

ensure_darwin_only "brew"
check_deployment_conflicts "brew"

if ! command -v brew &>/dev/null; then
	echo -e "${RED}Homebrew not found in PATH${RESET}" >&2
	echo -e "${YELLOW}You can install it by running: ${WHITE}~/.local/bin/brew-install${RESET}" >&2
	exit 1
fi

echo -e "${GREEN}Running Homebrew sync...${RESET}"

if brew-sync; then
	notify_success "Brew"
else
	notify_error "Brew"
	echo
	echo -e "${RED}Brew sync failed!${RESET}" >&2
	exit 1
fi
