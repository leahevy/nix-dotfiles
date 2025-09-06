#!/usr/bin/env bash
set -euo pipefail

NIX_VERSION="2.30.2"
NIX_CHECKSUM="72871bd265ff3a9da7af486b42f39695591cdb7cd855140eaabce389dbd46f7c"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REPO_ROOT="$(cd "$SCRIPT_DIR/../../../" && pwd)"
cd "$REPO_ROOT"
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

if [[ "$(whereis -b nix)" == *"nix:" ]]; then
  echo -e "${GREEN}Installing nix...${RESET}" >&2
  unameOut="$(uname -s)"
  case "${unameOut}" in
      Linux*)
          echo -e "${GREEN}Detected running on Linux (using Nix version $NIX_VERSION)${RESET}" >&2
          TEMP_DIR=$(mktemp -d)
          INSTALLER="$TEMP_DIR/nix-installer"
          curl --proto '=https' --tlsv1.2 -L "https://releases.nixos.org/nix/nix-$NIX_VERSION/install" -o "$INSTALLER"
          echo -e "${GREEN}Verifying installer checksum...${RESET}" >&2
          echo "$NIX_CHECKSUM  $INSTALLER" | sha256sum -c || { echo -e "${RED}Checksum verification failed!${RESET}"; exit 1; }
          sh "$INSTALLER" --daemon
          rm -rf "$TEMP_DIR"
          ;;
      Darwin*)
          echo -e "${GREEN}Detected running on Mac (using Nix version $NIX_VERSION)${RESET}" >&2
          TEMP_DIR=$(mktemp -d)
          INSTALLER="$TEMP_DIR/nix-installer"
          curl --proto '=https' --tlsv1.2 -L "https://releases.nixos.org/nix/nix-$NIX_VERSION/install" -o "$INSTALLER"
          echo -e "${GREEN}Verifying installer checksum...${RESET}" >&2
          echo "$NIX_CHECKSUM  $INSTALLER" | shasum -a 256 -c || { echo -e "${RED}Checksum verification failed!${RESET}"; exit 1; }
          sh "$INSTALLER"
          rm -rf "$TEMP_DIR"
          ;;
      *)
          echo -e "${RED}Did not detect Mac or Linux -> aborting installation...${RESET}" >&2
          exit 1
          ;;
  esac
else
  echo -e "${GREEN}Skipping nix installation as it is already installed...${RESET}" >&2
fi

echo -e "${GREEN}Fixing permissions on $(pwd)${RESET}" >&2
chmod 700 "."

echo >&2
echo -e "${GREEN}Nix installation completed!${RESET}" >&2
echo -e "${MAGENTA}Next steps:${RESET}" >&2
echo -e "${MAGENTA}  1. Ensure your config is available${RESET}" >&2
echo -e "${MAGENTA}  2. Run ${WHITE}10-create-sops-key.sh${MAGENTA} to create encryption keys and follow instructions${RESET}" >&2
echo -e "${MAGENTA}  3. Run ${WHITE}20-initial-sync.sh${MAGENTA} to apply configuration${RESET}" >&2
