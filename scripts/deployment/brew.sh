#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
simple_deployment_script_setup "brew"

ensure_darwin_only "brew"

BREWFILE="$HOME/.config/homebrew/Brewfile"

if [[ ! -f "$BREWFILE" ]]; then
    echo -e "${RED}Brewfile not found at ${WHITE}$BREWFILE${RESET}" >&2
    echo -e "${YELLOW}Try running ${GREEN}nx sync${YELLOW} first to generate the Brewfile${RESET}" >&2
    exit 1
fi

if ! command -v brew &> /dev/null; then
    echo -e "${RED}Homebrew not found in PATH${RESET}" >&2
    echo -e "${YELLOW}You can install it by running: ${WHITE}~/.local/bin/brew-install${RESET}" >&2
    exit 1
fi

echo -e "${GREEN}Running Homebrew sync...${RESET}"

if ! brew-sync; then
    echo
    echo -e "${RED}Brew sync failed!${RESET}" >&2
    exit 1
fi
