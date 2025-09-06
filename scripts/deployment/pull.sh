#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
deployment_script_setup "pull"

echo -e "${GREEN}Pulling main repository ${WHITE}(.config/nx/nxcore)${RESET}..."
git pull "$@"

if [[ -d "$CONFIG_DIR/.git" ]]; then
    echo
    echo -e "${GREEN}Pulling config repository ${WHITE}(.config/nx/nxconfig)${RESET}..."
    (cd "$CONFIG_DIR" && git pull "$@")
    echo
    echo -e "${GREEN}Both repositories pulled successfully.${RESET}"
else
    echo
    echo -e "${YELLOW}Warning: Config directory does not exist or is no directory.${RESET}"
fi
