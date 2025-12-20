#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
deployment_script_setup "update"
check_deployment_conflicts "update"

if [[ $# -eq 0 ]]; then
    echo -e "Updating nixpkgs input of main repository ${WHITE}(.config/nx/nxcore)${RESET}..."
    nix flake update nixpkgs || true
else
    echo -e "Updating flake of main repository ${WHITE}(.config/nx/nxcore)${RESET}..."
    nix flake update "$@" || true
fi

if [[ -d "$CONFIG_DIR/.git" ]]; then
    echo
    if [[ $# -eq 0 ]]; then
        echo -e "Updating nixpkgs input of config repository ${WHITE}(.config/nx/nxconfig)${RESET}..."
        (cd "$CONFIG_DIR" && nix flake update nixpkgs || true)
    else
        echo -e "Updating flake of config repository ${WHITE}(.config/nx/nxconfig)${RESET}..."
        (cd "$CONFIG_DIR" && nix flake update "$@" || true)
    fi
else
    echo
    echo -e "${YELLOW}Warning: Config directory does not exist or is no directory.${RESET}"
fi

echo
echo -e "Regenerating auto-upgrade reboot marker files..."
sha256sum flake.lock | cut -d' ' -f1 > .nx-auto-upgrade-reboot-required
sha256sum flake.lock | cut -d' ' -f1 > .nx-auto-upgrade-desktop-reboot-required
echo -e "Created marker files with hash: $(cat .nx-auto-upgrade-reboot-required)"
