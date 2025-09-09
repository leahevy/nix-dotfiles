#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
deployment_script_setup "addp"
parse_git_args "$@"

if [[ "$ONLY_CONFIG" != true ]]; then
    echo -e "${GREEN}Add ${YELLOW}--patch ${GREEN}files in main repository ${WHITE}(.config/nx/nxcore)${RESET}..."
    if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
        git add --patch "${EXTRA_ARGS[@]}" || true
    else
        git add --patch || true
    fi
fi

if [[ "$ONLY_CORE" != true ]] && [[ -d "$CONFIG_DIR/.git" ]]; then
    if [[ "$ONLY_CONFIG" != true ]]; then
        echo
    fi
    echo -e "${GREEN}Add ${YELLOW}--patch ${GREEN}files in config repository ${WHITE}(.config/nx/nxconfig)${RESET}..."
    if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
        (cd "$CONFIG_DIR" && git add --patch "${EXTRA_ARGS[@]}" || true)
    else
        (cd "$CONFIG_DIR" && git add --patch || true)
    fi
elif [[ "$ONLY_CORE" != true ]] && [[ "$ONLY_CONFIG" != true ]]; then
    echo
    echo -e "${YELLOW}Warning: Config directory does not exist or is no directory.${RESET}"
fi
