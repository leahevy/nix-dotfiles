#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
deployment_script_setup "addp"
parse_git_args "$@"

if [[ "$ONLY_CONFIG" != true ]]; then
    echo -e "${GREEN}Add ${YELLOW}--patch ${GREEN}files in main repository ${WHITE}(.config/nx/nxcore)${RESET}..."
    git add --patch "${EXTRA_ARGS[@]}" || true
fi

if [[ "$ONLY_CORE" != true ]] && [[ -d "$CONFIG_DIR/.git" ]]; then
    if [[ "$ONLY_CONFIG" != true ]]; then
        echo
    fi
    echo -e "${GREEN}Add ${YELLOW}--patch ${GREEN}files in config repository ${WHITE}(.config/nx/nxconfig)${RESET}..."
    (cd "$CONFIG_DIR" && git add --patch "${EXTRA_ARGS[@]}" || true)
elif [[ "$ONLY_CORE" != true ]] && [[ "$ONLY_CONFIG" != true ]]; then
    echo
    echo -e "${YELLOW}Warning: Config directory does not exist or is no directory.${RESET}"
fi
