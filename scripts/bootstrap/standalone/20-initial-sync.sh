#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REPO_ROOT="$(cd "$SCRIPT_DIR/../../../" && pwd)"
cd "$REPO_ROOT"
export BOOTSTRAP_NEEDS_NIX=true
source "$REPO_ROOT/scripts/utils/pre-check.sh"

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

TARGET_FILE="$HOME/.config/sops/age/keys.txt"
if [[ ! -f "$TARGET_FILE" ]]; then
  echo -e "${RED}Error: Sops key not found at ${WHITE}$TARGET_FILE${RESET}" >&2
  echo -e "${RED}Please run ${WHITE}scripts/bootstrap/standalone/10-create-sops-key.sh${RED} first to create sops key and follow instructions${RESET}" >&2
  exit 1
fi

if [[ -x "$HOME/.nix-profile/bin/home-manager" ]]; then
  echo -e "${GREEN}Home Manager already configured and available in ${WHITE}~/.nix-profile/bin/${RESET}" >&2
  echo -e "${GREEN}Skipping initial sync - use '${WHITE}nx sync${GREEN}' for future updates${RESET}" >&2
  exit 0
fi

FULL_PROFILE="$(construct_profile_name "$USER")"
PROFILE_PATH="$(retrieve_active_profile_path)"
echo -e "${GREEN}Building Home Manager configuration for ${WHITE}$FULL_PROFILE${GREEN} with config override${RESET}" >&2

CLEANUP_RESULT=1
cleanup() {
  if [[ -d "./result" ]]; then
    if (( CLEANUP_RESULT )); then
      CLEANUP_RESULT=0
      echo -e "${WHITE}Cleaning up ./result folder...${RESET}" >&2
      rm -rf "./result"
    fi
  fi
}
trap cleanup EXIT ERR

nix build --extra-experimental-features flakes --extra-experimental-features nix-command \
  ".#homeConfigurations.$FULL_PROFILE.activationPackage" \
  --override-input config "path:$CONFIG_DIR" --override-input profile "path:$PROFILE_PATH" >&2

echo -e "${GREEN}Activating Home Manager configuration${RESET}" >&2
if ./result/activate; then
  echo >&2
  echo -e "${GREEN}Configuration activated successfully!${RESET}" >&2
  echo >&2
  echo -e "${MAGENTA}Next steps:${RESET}" >&2
  echo -e "${MAGENTA}  - Restart the whole system to ensure that everything is applied correctly!${RESET}" >&2
else
  CLEANUP_RESULT=0
  echo >&2
  echo -e "${YELLOW}The activate script returned an error code but the configuration may still be partially active!${RESET}" >&2
  echo >&2
  echo -e "${YELLOW}A common error is that files are in the way of the home-manager config, e.g.:${RESET}" >&2
  echo -e "${YELLOW}   - ${WHITE}$HOME/.bashrc${RESET}" >&2
  echo -e "${YELLOW}   - ${WHITE}$HOME/.profile${RESET}" >&2
  echo -e "${YELLOW}   - ${WHITE}$HOME/.config/user-dirs.dirs${RESET}" >&2
  echo >&2
  echo -e "${MAGENTA}If this is the case:${RESET}" >&2
  echo -e "${MAGENTA}  1. Remove the files and then run manually ${WHITE}$(pwd)/result/activate${RESET}" >&2
  echo -e "${MAGENTA}  2. Then manually remove the folder/symlink: ${WHITE}rm -rf $(pwd)/result${RESET}" >&2
  echo -e "${MAGENTA}  3. Restart the whole system to ensure that everything will be applied correctly!${RESET}" >&2
fi

echo >&2
echo -e "${GREEN}The '${WHITE}nx${GREEN}' command should be available in a new shell!${RESET}" >&2

