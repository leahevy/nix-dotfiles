#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
deployment_script_setup "dist-upgrade"
check_deployment_conflicts "dist-upgrade"

if [[ $# -ne 1 ]]; then
    echo -e "${RED}Error: dist-upgrade requires exactly one argument${RESET}" >&2
    echo >&2
    echo -e "Usage: ${WHITE}nx dist-upgrade <NIXOS_VERSION>${RESET}" >&2
    echo -e "Example: ${WHITE}nx dist-upgrade 25.11${RESET}" >&2
    exit 1
fi

NIXOS_VERSION="$1"

if ! [[ "$NIXOS_VERSION" =~ ^[0-9][0-9]\.[0-9][0-9]$ ]]; then
    echo -e "${RED}Error: Invalid NixOS version format${RESET}" >&2
    echo >&2
    echo -e "Expected format: ${WHITE}XX.XX${RESET} (e.g., 25.11)" >&2
    echo -e "Received: ${WHITE}$NIXOS_VERSION${RESET}" >&2
    exit 1
fi

echo -e "Bumping NixOS version to ${WHITE}$NIXOS_VERSION${RESET}..."
echo

check_git_worktrees_clean

echo -e "Updating version references in ${WHITE}nxcore/flake.nix${RESET}..."
sed -i "s/[0-9][0-9]\.[0-9][0-9]/$NIXOS_VERSION/g" flake.nix

echo -e "Updating version references in ${WHITE}nxcore/src/nxconfig/flake.nix${RESET}..."
sed -i "s/[0-9][0-9]\.[0-9][0-9]/$NIXOS_VERSION/g" src/nxconfig/flake.nix

if [[ -d "$CONFIG_DIR/.git" ]]; then
    echo -e "Updating version references in ${WHITE}nxconfig/flake.nix${RESET}..."
    (cd "$CONFIG_DIR" && sed -i "s/[0-9][0-9]\.[0-9][0-9]/$NIXOS_VERSION/g" flake.nix)
fi

echo
echo -e "Migrating packages from unstable to stable in ${WHITE}nxcore/src${RESET}..."

find src -name "*.nix" -type f -not -path "src/nxconfig/*" -exec sed -i 's/with pkgs-unstable/with pkgs/g' {} \;
find src -name "*.nix" -type f -not -path "src/nxconfig/*" -exec sed -i 's/pkgs-unstable\./pkgs\./g' {} \;
find src -name "*.nix" -type f -not -path "src/nxconfig/*" -exec sed -i 's/self\.pkgs-unstable/self\.pkgs/g' {} \;

if [[ -d "$CONFIG_DIR/.git" ]]; then
    echo -e "Migrating packages from unstable to stable in ${WHITE}nxconfig/modules${RESET}..."

    (cd "$CONFIG_DIR" && find modules -name "*.nix" -type f -exec sed -i 's/with pkgs-unstable/with pkgs/g' {} \; 2>/dev/null || true)
    (cd "$CONFIG_DIR" && find modules -name "*.nix" -type f -exec sed -i 's/pkgs-unstable\./pkgs\./g' {} \; 2>/dev/null || true)
    (cd "$CONFIG_DIR" && find modules -name "*.nix" -type f -exec sed -i 's/self\.pkgs-unstable/self\.pkgs/g' {} \; 2>/dev/null || true)
fi

echo
echo -e "Updating flake inputs for ${WHITE}nxcore${RESET}..."
nix flake update nixpkgs home-manager stylix nixvim nix-darwin nixpkgs-unstable || true

if [[ -d "$CONFIG_DIR/.git" ]]; then
    echo
    echo -e "Updating flake inputs for ${WHITE}nxconfig${RESET}..."
    (cd "$CONFIG_DIR" && nix flake update nixpkgs nixpkgs-unstable || true)
fi

echo
echo -e "Regenerating auto-upgrade reboot marker files..."
sha256sum flake.lock | cut -d' ' -f1 > .nx-auto-upgrade-reboot-required
sha256sum flake.lock | cut -d' ' -f1 > .nx-auto-upgrade-desktop-reboot-required
echo -e "Created marker files with hash: $(cat .nx-auto-upgrade-reboot-required)"

echo
echo -e "${GREEN}NixOS version bump to $NIXOS_VERSION completed successfully!${RESET}"
echo
echo -e "${YELLOW}Next steps: Please read UPGRADE.md for the complete upgrade process${RESET}"
