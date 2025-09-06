#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
deployment_script_setup "format"

echo -e "${GREEN}Formatting main repository ${WHITE}(.config/nx/nxcore)${RESET}..."
treefmt . "$@"

if [[ -d "$CONFIG_DIR/.git" ]]; then
    echo
    echo -e "${GREEN}Formatting config repository ${WHITE}(.config/nx/nxconfig)${RESET}..."
    (cd "$CONFIG_DIR" && treefmt . "$@")
else
    echo
    echo -e "${YELLOW}Warning: Config directory does not exist or is no directory.${RESET}"
fi

