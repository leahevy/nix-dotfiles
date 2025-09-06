#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
deployment_script_setup "push"

echo -e "${GREEN}Pushing main repository ${WHITE}(.config/nx/nxcore)${RESET}..."
git push "$@"

if [[ -d "$CONFIG_DIR/.git" ]]; then
    echo
    echo -e "${GREEN}Pushing config repository ${WHITE}(.config/nx/nxconfig)${RESET}..."
    (cd "$CONFIG_DIR" && git push "$@")
    echo
    echo -e "${GREEN}Both repositories pushed successfully.${RESET}"
else
    echo
    echo -e "${YELLOW}Warning: Config directory is not a git repository, skipping push.${RESET}"
fi
