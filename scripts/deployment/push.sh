#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
deployment_script_setup "push"
parse_git_args "$@"

if [[ "$ONLY_CONFIG" != true ]]; then
    echo -e "${GREEN}Pushing main repository ${WHITE}(.config/nx/nxcore)${RESET}..."
    git push "${EXTRA_ARGS[@]}"
fi

if [[ "$ONLY_CORE" != true ]] && [[ -d "$CONFIG_DIR/.git" ]]; then
    if [[ "$ONLY_CONFIG" != true ]]; then
        echo
    fi
    echo -e "${GREEN}Pushing config repository ${WHITE}(.config/nx/nxconfig)${RESET}..."
    (cd "$CONFIG_DIR" && git push "${EXTRA_ARGS[@]}")
    if [[ "$ONLY_CONFIG" == true ]]; then
        echo
        echo -e "${GREEN}Config repository pushed successfully.${RESET}"
    else
        echo
        echo -e "${GREEN}Both repositories pushed successfully.${RESET}"
    fi
elif [[ "$ONLY_CORE" != true ]] && [[ "$ONLY_CONFIG" != true ]]; then
    echo
    echo -e "${YELLOW}Warning: Config directory is not a git repository, skipping push.${RESET}"
elif [[ "$ONLY_CORE" == true ]]; then
    echo
    echo -e "${GREEN}Main repository pushed successfully.${RESET}"
fi
