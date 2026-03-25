#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
deployment_script_setup "update"
check_deployment_conflicts "update"

old_flake_hash=$(sha256sum flake.lock | cut -d' ' -f1)

if [[ $# -eq 0 ]]; then
    echo -e "Updating nixpkgs input of main repository ${WHITE}(.config/nx/nxcore)${RESET}..."
    nix flake update nixpkgs home-manager stylix nixvim nix-darwin nixpkgs-unstable || true
else
    echo -e "Updating flake of main repository ${WHITE}(.config/nx/nxcore)${RESET}..."
    nix flake update "$@" || true
fi

if [[ -d "$CONFIG_DIR/.git" ]]; then
    echo
    if [[ $# -eq 0 ]]; then
        echo -e "Updating nixpkgs input of config repository ${WHITE}(.config/nx/nxconfig)${RESET}..."
        (cd "$CONFIG_DIR" && nix flake update nixpkgs nixpkgs-unstable || true)
    else
        echo -e "Updating flake of config repository ${WHITE}(.config/nx/nxconfig)${RESET}..."
        (cd "$CONFIG_DIR" && nix flake update "$@" || true)
    fi
else
    echo
    echo -e "${YELLOW}Warning: Config directory does not exist or is no directory.${RESET}"
fi

echo
new_flake_hash=$(sha256sum flake.lock | cut -d' ' -f1)
if [[ "$new_flake_hash" != "$old_flake_hash" ]]; then
    echo -e "${GREEN}NXCore flake lock changed, creating auto-upgrade reboot marker files...${RESET}"
    echo "$new_flake_hash" > .nx-auto-upgrade-reboot-required
    echo "$new_flake_hash" > .nx-auto-upgrade-desktop-reboot-required
    echo -e "Created marker files with hash: ${WHITE}$new_flake_hash${RESET}"
else
    echo -e "${YELLOW}NXCore flake lock unchanged, skipping marker file creation.${RESET}"
fi
