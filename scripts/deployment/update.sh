#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/common.sh"
deployment_script_setup "update"
check_deployment_conflicts "update"

matched_tp_inputs=()
if [[ $# -eq 0 ]]; then
    matched_tp_inputs=("${THIRD_PARTY_INPUTS[@]}")
else
    for input in "$@"; do
        for tp_input in "${THIRD_PARTY_INPUTS[@]}"; do
            if [[ "$input" == "$tp_input" ]]; then
                matched_tp_inputs+=("$tp_input")
            fi
        done
    done
fi

if [[ ${#matched_tp_inputs[@]} -gt 0 ]]; then
    echo -e "${YELLOW}This update includes third-party inputs: ${WHITE}${matched_tp_inputs[*]}${RESET}"
    echo -e "${YELLOW}These require manual review of upstream changes before updating.${RESET}"
    echo
    echo -e -n "${CYAN}Have you reviewed the changes in these repositories? [${GREEN}y${CYAN}/${RED}N${CYAN}]${RESET} "
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo -e "${RED}Aborting update.${RESET}"
        exit 1
    fi
fi

old_flake_hash=$(sha256sum "$NXCORE_DIR/flake.lock" | cut -d' ' -f1)

if [[ $# -eq 0 ]]; then
    echo -e "Updating inputs of core repository ${WHITE}(.config/nx/nxcore)${RESET}..."
    (cd "$NXCORE_DIR" && nix flake update "${AUTO_UPDATE_INPUTS[@]}" || true)
else
    echo -e "Updating inputs of core repository ${WHITE}(.config/nx/nxcore)${RESET}..."
    (cd "$NXCORE_DIR" && nix flake update "$@" || true)
    echo
    echo -e "Updating inputs of config repository ${WHITE}(.config/nx/nxconfig)${RESET}..."
    nix flake update "$@" || true
fi

echo
new_flake_hash=$(sha256sum "$NXCORE_DIR/flake.lock" | cut -d' ' -f1)
if [[ "$new_flake_hash" != "$old_flake_hash" ]]; then
    echo -e "${GREEN}NXCore flake lock changed, creating auto-upgrade reboot marker files...${RESET}"
    echo "$new_flake_hash" > "$NXCORE_DIR/.nx-auto-upgrade-reboot-required"
    echo "$new_flake_hash" > "$NXCORE_DIR/.nx-auto-upgrade-desktop-reboot-required"
    echo -e "Created marker files with hash: ${WHITE}$new_flake_hash${RESET}"
else
    echo -e "${YELLOW}NXCore flake lock unchanged, skipping marker file creation.${RESET}"
fi
