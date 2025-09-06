#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
deployment_script_setup "add"

echo -e "${GREEN}Add files in main repository ${WHITE}(.config/nx/nxcore)${RESET}..."
git add . --verbose "$@" || true

if [[ -d "$CONFIG_DIR/.git" ]]; then
    echo
    echo -e "${GREEN}Add files in config repository ${WHITE}(.config/nx/nxconfig)${RESET}..."
    (cd "$CONFIG_DIR" && git add . --verbose "$@" || true)
else
    echo
    echo -e "${YELLOW}Warning: Config directory does not exist or is no directory.${RESET}"
fi
