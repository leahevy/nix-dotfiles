#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
deployment_script_setup "update"
check_deployment_conflicts "update"

echo -e "Updating flake of main repository ${WHITE}(.config/nx/nxcore)${RESET}..."
nix flake update "$@" || true

if [[ -d "$CONFIG_DIR/.git" ]]; then
    echo
    echo -e "Updating flake of config repository ${WHITE}(.config/nx/nxconfig)${RESET}..."
    (cd "$CONFIG_DIR" && nix flake update "$@" || true)
else
    echo
    echo -e "${YELLOW}Warning: Config directory does not exist or is no directory.${RESET}"
fi
