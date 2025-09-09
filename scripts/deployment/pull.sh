#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
deployment_script_setup "pull"
parse_git_args "$@"

if [[ "$ONLY_CONFIG" != true ]]; then
    echo -e "${GREEN}Pulling main repository ${WHITE}(.config/nx/nxcore)${RESET}..."
    if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
        git pull "${EXTRA_ARGS[@]}"
    else
        git pull
    fi
fi

if [[ "$ONLY_CORE" != true ]] && [[ -d "$CONFIG_DIR/.git" ]]; then
    if [[ "$ONLY_CONFIG" != true ]]; then
        echo
    fi
    echo -e "${GREEN}Pulling config repository ${WHITE}(.config/nx/nxconfig)${RESET}..."
    if [[ ${#EXTRA_ARGS[@]} -gt 0 ]]; then
        (cd "$CONFIG_DIR" && git pull "${EXTRA_ARGS[@]}")
    else
        (cd "$CONFIG_DIR" && git pull)
    fi
    if [[ "$ONLY_CONFIG" == true ]]; then
        echo
        echo -e "${GREEN}Config repository pulled successfully.${RESET}"
    else
        echo
        echo -e "${GREEN}Both repositories pulled successfully.${RESET}"
    fi
elif [[ "$ONLY_CORE" != true ]] && [[ "$ONLY_CONFIG" != true ]]; then
    echo
    echo -e "${YELLOW}Warning: Config directory does not exist or is no directory.${RESET}"
elif [[ "$ONLY_CORE" == true ]]; then
    echo
    echo -e "${GREEN}Main repository pulled successfully.${RESET}"
fi
