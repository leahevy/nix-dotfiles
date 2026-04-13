#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/common.sh"
deployment_script_setup "bump"
check_deployment_conflicts "bump"

unpushed=$(git -C "$NXCORE_DIR" log origin/HEAD..HEAD --oneline 2>/dev/null || true)
if [[ -n "$unpushed" ]]; then
    echo -e "${YELLOW}Warning: nxcore has unpushed commits:${RESET}"
    echo
    echo "$unpushed" | while IFS= read -r line; do
        echo -e "  ${WHITE}$line${RESET}"
    done
    echo
    echo -e "${YELLOW}Bumping now will lock to the current remote HEAD, not your local commits.${RESET}"
    echo
    echo -e -n "${CYAN}Bump anyway? [${GREEN}y${CYAN}/${RED}N${CYAN}]${RESET} "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo -e "${RED}Aborting. Push nxcore first, then run bump again.${RESET}"
        exit 1
    fi
fi

echo -e "Bumping ${WHITE}core${RESET} input of config repository ${WHITE}(.config/nx/nxconfig)${RESET}..."
nix flake update core
