#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
deployment_script_setup "status"
parse_git_args "$@"

if [[ "$ONLY_CONFIG" != true ]]; then
    echo -e "${GREEN}Status of main repository ${WHITE}(.config/nx/nxcore)${RESET}..."
    if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
        git status --porcelain "${EXTRA_ARGS[@]}"
    else
        git status --porcelain
    fi
fi

if [[ "$ONLY_CORE" != true ]] && [[ -d "$CONFIG_DIR/.git" ]]; then
    if [[ "$ONLY_CONFIG" != true ]]; then
        echo
    fi
    echo -e "${GREEN}Status of config repository ${WHITE}(.config/nx/nxconfig)${RESET}..."
    if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
        (cd "$CONFIG_DIR" && git status --porcelain "${EXTRA_ARGS[@]}")
    else
        (cd "$CONFIG_DIR" && git status --porcelain)
    fi
elif [[ "$ONLY_CORE" != true ]] && [[ "$ONLY_CONFIG" != true ]]; then
    echo
    echo -e "${YELLOW}Warning: Config directory does not exist or is no directory.${RESET}"
fi
