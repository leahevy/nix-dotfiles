#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
deployment_script_setup "log"
parse_git_args "$@"

if [[ "$ONLY_CONFIG" != true ]]; then
    echo -e "${GREEN}Logs of main repository ${WHITE}(.config/nx/nxcore)${RESET}..."
    git log HEAD~5..HEAD "${EXTRA_ARGS[@]}"
fi

if [[ "$ONLY_CORE" != true ]] && [[ -d "$CONFIG_DIR/.git" ]]; then
    if [[ "$ONLY_CONFIG" != true ]]; then
        echo
    fi
    echo -e "${GREEN}Logs of config repository ${WHITE}(.config/nx/nxconfig)${RESET}..."
    (cd "$CONFIG_DIR" && git log HEAD~5..HEAD "${EXTRA_ARGS[@]}")
elif [[ "$ONLY_CORE" != true ]] && [[ "$ONLY_CONFIG" != true ]]; then
    echo
    echo -e "${YELLOW}Warning: Config directory does not exist or is no directory.${RESET}"
fi
