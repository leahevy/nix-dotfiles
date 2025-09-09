#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
deployment_script_setup "diffc"
parse_git_args "$@"

if [[ "$ONLY_CONFIG" != true ]]; then
    echo -e "${GREEN}Diff ${YELLOW}--cached ${GREEN}of main repository ${WHITE}(.config/nx/nxcore)${RESET}..."
    git diff --cached "${EXTRA_ARGS[@]}"
fi

if [[ "$ONLY_CORE" != true ]] && [[ -d "$CONFIG_DIR/.git" ]]; then
    if [[ "$ONLY_CONFIG" != true ]]; then
        echo
    fi
    echo -e "${GREEN}Diff ${YELLOW}--cached ${GREEN}of config repository ${WHITE}(.config/nx/nxconfig)${RESET}..."
    (cd "$CONFIG_DIR" && git diff --cached "${EXTRA_ARGS[@]}")
elif [[ "$ONLY_CORE" != true ]] && [[ "$ONLY_CONFIG" != true ]]; then
    echo
    echo -e "${YELLOW}Warning: Config directory does not exist or is no directory.${RESET}"
fi
