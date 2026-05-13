#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/common.sh"
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
sed -i "s/[0-9][0-9]\.[0-9][0-9]/$NIXOS_VERSION/g" "$NXCORE_DIR/flake.nix"

echo -e "Updating state-version in ${WHITE}nxcore/variables.nix${RESET}..."
sed -i "s/state-version = \"[0-9][0-9]\.[0-9][0-9]\"/state-version = \"$NIXOS_VERSION\"/g" "$NXCORE_DIR/variables.nix"

echo -e "Updating stateVersion in ${WHITE}nxcore/templates${RESET}..."
find "$NXCORE_DIR/templates" -name "*.nix" -type f -exec sed -i "s/stateVersion = \"[0-9][0-9]\.[0-9][0-9]\"/stateVersion = \"$NIXOS_VERSION\"/g" {} \;

echo -e "Updating stateVersion fallback in ${WHITE}nxcore/scripts/bootstrap/nixos/50-create-profile-stub.sh${RESET}..."
sed -i '/STATE_VERSION_VALUE=/s/[0-9][0-9]\.[0-9][0-9]/'"$NIXOS_VERSION"'/' "$NXCORE_DIR/scripts/bootstrap/nixos/50-create-profile-stub.sh"

CURRENT_PYTHON=$(grep 'pythonName' "$NXCORE_DIR/variables.nix" | grep -oE 'python[0-9]+' | head -n1 || true)
echo
echo -e "${YELLOW}Action required: verify pythonName in nxcore/variables.nix for NixOS $NIXOS_VERSION.${RESET}"
[[ -n "$CURRENT_PYTHON" ]] && echo -e "${YELLOW}Current value is ${WHITE}$CURRENT_PYTHON${YELLOW}. Update it if the default Python version changed for this NixOS release.${RESET}"
echo

if [[ -d "$CONFIG_DIR/.git" ]]; then
	echo -e "Updating version references in ${WHITE}nxconfig/flake.nix${RESET}..."
	(cd "$CONFIG_DIR" && sed -i "s/[0-9][0-9]\.[0-9][0-9]/$NIXOS_VERSION/g" flake.nix)

	if [[ -f "$CONFIG_DIR/variables.nix" ]]; then
		echo -e "Updating state-version in ${WHITE}nxconfig/variables.nix${RESET}..."
		(cd "$CONFIG_DIR" && sed -i "s/state-version = \"[0-9][0-9]\.[0-9][0-9]\"/state-version = \"$NIXOS_VERSION\"/g" variables.nix)
	fi
fi

echo
echo -e "Migrating packages from unstable to stable in ${WHITE}nxcore/src${RESET}..."

find "$NXCORE_DIR/src" -name "*.nix" -type f -exec sed -i 's/with pkgs-unstable/with pkgs/g' {} \;
find "$NXCORE_DIR/src" -name "*.nix" -type f -exec sed -i 's/pkgs-unstable\./pkgs\./g' {} \;
find "$NXCORE_DIR/src" -name "*.nix" -type f -exec sed -i 's/self\.pkgs-unstable/self\.pkgs/g' {} \;

if [[ -d "$CONFIG_DIR/.git" ]]; then
	echo -e "Migrating packages from unstable to stable in ${WHITE}nxconfig/modules${RESET}..."

	(cd "$CONFIG_DIR" && find modules -name "*.nix" -type f -exec sed -i 's/with pkgs-unstable/with pkgs/g' {} \; 2>/dev/null || true)
	(cd "$CONFIG_DIR" && find modules -name "*.nix" -type f -exec sed -i 's/pkgs-unstable\./pkgs\./g' {} \; 2>/dev/null || true)
	(cd "$CONFIG_DIR" && find modules -name "*.nix" -type f -exec sed -i 's/self\.pkgs-unstable/self\.pkgs/g' {} \; 2>/dev/null || true)
fi

echo
echo -e "Updating flake inputs for ${WHITE}nxcore${RESET}..."
(cd "$NXCORE_DIR" && nix flake update "${AUTO_UPDATE_INPUTS[@]}" || true)

if [[ -d "$CONFIG_DIR/.git" ]]; then
	echo
	echo -e "Updating flake inputs for ${WHITE}nxconfig${RESET}..."
	(cd "$CONFIG_DIR" && nix flake update nixpkgs nixpkgs-unstable || true)
fi

echo
echo -e "Regenerating auto-upgrade reboot marker files..."
mkdir -p "$NXCORE_DIR/.core-state"
core_flake_hash=$(sha256sum "$NXCORE_DIR/flake.lock" | cut -d' ' -f1)
echo "$core_flake_hash" >"$NXCORE_DIR/.core-state/reboot-required"
echo "$core_flake_hash" >"$NXCORE_DIR/.core-state/desktop-reboot-required"
echo -e "Created marker files with hash: ${WHITE}$core_flake_hash${RESET}"

echo
echo -e "${GREEN}NixOS version bump to $NIXOS_VERSION completed successfully!${RESET}"
echo
echo -e "${YELLOW}Next steps: Please read UPGRADE.md for the complete upgrade process${RESET}"
