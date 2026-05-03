#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REPO_ROOT="$(cd "$SCRIPT_DIR/../../../" && pwd)"
export BOOTSTRAP_NEEDS_NIX=true
source "$REPO_ROOT/scripts/utils/common.sh"

if [[ -e /etc/NIXOS ]]; then
	echo -e "${RED}Detected NixOS -> aborting standalone bootstrap...${RESET}" >&2
	exit 1
fi

if [[ "$UID" = 0 ]]; then
	echo -e "${RED}Do NOT run as root!${RESET}" >&2
	exit 1
fi

check_config_directory "select-profile" "bootstrap"
cd "$CONFIG_DIR"

if [[ "$(pwd)" != "$HOME/.config/nx/nxconfig" ]]; then
	echo -e "${RED}Error: the config repository has to be cloned to ${WHITE}$HOME/.config/nx/nxconfig${RESET}" >&2
	exit 1
fi

PROFILE="${1:-}"
if [[ "$PROFILE" =~ ^- ]]; then
	echo -e "${RED}Error: Unknown option ${WHITE}$PROFILE${RESET}" >&2
	echo -e "${RED}Usage: ${WHITE}$0${RED} <PROFILE>${RESET}" >&2
	exit 1
fi

if [[ -z "$PROFILE" ]]; then
	echo -e "${RED}Usage: ${WHITE}$0${RED} <PROFILE>${RESET}" >&2
	echo -e "${RED}Select a profile from ${WHITE}$CONFIG_DIR/profiles/home-standalone${RED}!${RESET}" >&2
	exit 1
fi

if [[ ! -d "$CONFIG_DIR/profiles/home-standalone/$PROFILE" ]]; then
	echo -e "${RED}Error: Profile ${WHITE}$PROFILE${RED} does not exist in ${WHITE}$CONFIG_DIR/profiles/home-standalone${RESET}" >&2
	exit 1
fi

echo -n "$PROFILE" >.nx-profile.conf
echo -e "${GREEN}Selected standalone profile: ${WHITE}$PROFILE${RESET}"
