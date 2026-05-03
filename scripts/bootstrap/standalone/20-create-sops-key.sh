#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REPO_ROOT="$(cd "$SCRIPT_DIR/../../../" && pwd)"
cd "$REPO_ROOT"
export BOOTSTRAP_NEEDS_NIX=true
source "$REPO_ROOT/scripts/utils/common.sh"

if [[ -e /etc/NIXOS ]]; then
	echo -e "${RED}Detected NixOS -> aborting installation...${RESET}" >&2
	exit 1
fi

if [[ "$UID" = 0 ]]; then
	echo -e "${RED}Do NOT run as root!${RESET}" >&2
	exit 1
fi

if [[ "$(pwd)" != "$HOME/.config/nx/nxcore" ]]; then
	echo -e "${RED}Error: the repository has to be cloned to ${WHITE}$HOME/.config/nx/nxcore${RESET}" >&2
	exit 1
fi

check_config_directory "standalone-sync" "deployment"

TARGET_DIR="$HOME/.config/sops/age"
TARGET_FILE="$TARGET_DIR/keys.txt"

if [[ -f "$TARGET_FILE" ]]; then
	echo -e "${GREEN}Sops key already exists, skipping creation.${RESET}" >&2
else
	echo -e "${GREEN}Creating sops key for home-manager...${RESET}" >&2

	mkdir -p "$TARGET_DIR"
	nix-shell -p age --run "age-keygen -o $TARGET_FILE"
	chmod 600 "$TARGET_FILE"
	echo -e "${GREEN}Sops key created successfully${RESET}" >&2
fi

echo >&2
echo -e "🔑 Age public key:" >&2
nix-shell -p age --run "age-keygen -y $TARGET_FILE"

echo >&2
echo -e "${YELLOW}Next steps:${RESET}" >&2
echo -e "${YELLOW}  1. Add the generated sops public key to the config directory ${WHITE}.sops.yaml${YELLOW} file ${YELLOW}(on another host if there are already existing secrets!)${RESET}" >&2
echo -e "${YELLOW}  2. Run ${WHITE}updatekeys.sh${YELLOW} script in config directory to re-encrypt with the new age key${RESET}" >&2
echo -e "${YELLOW}  3. Run ${WHITE}nx bootstrap standalone initial-sync${YELLOW} to apply configuration${RESET}" >&2
