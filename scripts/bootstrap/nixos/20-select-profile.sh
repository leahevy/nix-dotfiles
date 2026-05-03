#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REPO_ROOT="$(cd "$SCRIPT_DIR/../../../" && pwd)"
cd "$REPO_ROOT"

export BOOTSTRAP_NEEDS_NIX=true
source "$REPO_ROOT/scripts/utils/common.sh"

if [[ ! -e /etc/NIXOS ]]; then
	echo -e "${RED}Did not detect NixOS -> aborting bootstrap...${RESET}" >&2
	exit 1
fi

check_config_directory "select-profile" "bootstrap"
cd "$CONFIG_DIR"

PROFILE="${1:-}"
if [[ "$PROFILE" =~ ^- ]]; then
	echo -e "${RED}Error: Unknown option ${WHITE}$PROFILE${RESET}" >&2
	echo -e "${RED}Usage: ${WHITE}$0${RED} <HOSTNAME>${RESET}" >&2
	exit 1
fi

if [[ -z "$PROFILE" ]]; then
	echo -e "${RED}Usage: ${WHITE}$0${RED} <HOSTNAME>${RESET}" >&2
	echo -e "${RED}Select a host from ${WHITE}$CONFIG_DIR/profiles/nixos${RED}!${RESET}" >&2
	exit 1
fi

if [[ ! -d "$CONFIG_DIR/profiles/nixos/$PROFILE" ]]; then
	echo -e "${RED}Error: Host ${WHITE}$PROFILE${RED} does not exist in ${WHITE}$CONFIG_DIR/profiles/nixos${RESET}" >&2
	exit 1
fi

echo -n "$PROFILE" >.nx-profile.conf
echo -e "${GREEN}Selected NixOS host profile: ${WHITE}$PROFILE${RESET}"
