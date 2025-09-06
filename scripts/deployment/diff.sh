#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
deployment_script_setup "diff"

echo -e "${GREEN}Diff of main repository ${WHITE}(.config/nx/nxcore)${RESET}..."
git diff "$@"

if [[ -d "$CONFIG_DIR/.git" ]]; then
    echo
    echo -e "${GREEN}Diff of config repository ${WHITE}(.config/nx/nxconfig)${RESET}..."
    (cd "$CONFIG_DIR" && git diff "$@")
else
    echo
    echo -e "${YELLOW}Warning: Config directory does not exist or is no directory.${RESET}"
fi
