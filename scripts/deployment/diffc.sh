#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
deployment_script_setup "diffc"

echo -e "${GREEN}Diff ${YELLOW}--cached ${GREEN}of main repository ${WHITE}(.config/nx/nxcore)${RESET}..."
git diff --cached "$@"

if [[ -d "$CONFIG_DIR/.git" ]]; then
    echo
    echo -e "${GREEN}Diff ${YELLOW}--cached ${GREEN}of config repository ${WHITE}(.config/nx/nxconfig)${RESET}..."
    (cd "$CONFIG_DIR" && git diff --cached "$@")
else
    echo
    echo -e "${YELLOW}Warning: Config directory does not exist or is no directory.${RESET}"
fi
