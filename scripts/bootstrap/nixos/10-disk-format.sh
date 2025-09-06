#!/usr/bin/env bash
set -euo pipefail

DISKO_VERSION="v1.12.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REPO_ROOT="$(cd "$SCRIPT_DIR/../../../" && pwd)"
cd "$REPO_ROOT"

export BOOTSTRAP_NEEDS_NIX=true
source "$REPO_ROOT/scripts/utils/pre-check.sh"

if [[ ! -e /etc/NIXOS ]]; then
  echo -e "${RED}Did not detect NixOS -> aborting installation...${RESET}" >&2
  exit 1
fi

if [[ "$UID" != 0 ]]; then
  echo -e "${RED}Requires root!${RESET}" >&2
  exit 1
fi

check_config_directory "disk-format" "bootstrap"

HOSTNAME="${1:-}"
if [[ "$HOSTNAME" = "" ]]; then
  echo -e "${RED}Run with ${WHITE}<HOSTNAME>${RED} argument (from ${WHITE}/nxconfig/profiles/nixos${RED})!${RESET}" >&2
  exit 1
fi

if [[ ! -e "$CONFIG_DIR/profiles/nixos/$HOSTNAME" ]]; then
  echo -e "${RED}Host ${WHITE}$HOSTNAME${RED} does not exist in ${WHITE}$CONFIG_DIR/profiles/nixos${RED}!${RESET}" >&2
  exit 1
fi

if [[ ! -e "$CONFIG_DIR/profiles/nixos/$HOSTNAME/disk.nix" ]]; then
  echo -e "${RED}Host ${WHITE}$HOSTNAME${RED} has no ${WHITE}disk.nix${RED} configuration in ${WHITE}$CONFIG_DIR/profiles/nixos${RED}!${RESET}" >&2
  exit 1
fi

ROOT_DEVICE=$(findmnt -n -o SOURCE /)
if [[ "$ROOT_DEVICE" =~ ^/dev/(sd[a-z]+[0-9]+|nvme[0-9]+n[0-9]+p[0-9]+|vd[a-z]+[0-9]+)$ ]]; then
  echo -e "${RED}Error: Cannot run disk formatting from an installed system!${RESET}" >&2
  echo -e "${WHITE}Root filesystem is mounted from: $ROOT_DEVICE${RESET}" >&2
  echo -e "${RED}This script can only be run from a live disk environment to prevent${RESET}" >&2
  echo -e "${RED}accidentally destroying the running system.${RESET}" >&2
  exit 1
fi

if mountpoint -q /mnt; then
  echo -e "${RED}Error: ${WHITE}/mnt${RED} is already mounted. Please unmount it before proceeding.${RESET}" >&2
  exit 1
fi

echo -e "${RED}WARNING: You are about to PERMANENTLY DESTROY ALL DATA on disks${RESET}"
echo -e "${RED}         configured in ${WHITE}$CONFIG_DIR/profiles/nixos/$HOSTNAME/disk.nix${RESET}"
echo
echo -e "${RED}ALL EXISTING DATA WILL BE LOST! THIS OPERATION CANNOT BE UNDONE!${RESET}"
echo
echo -e "${MAGENTA}Are you ABSOLUTELY SURE you want to DESTROY ALL DATA and proceed?${RESET}"
read -p "Continue? [y|N]: " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo -e "\n"
  echo -e "${GREEN}Running: ${WHITE}disko --mode destroy $CONFIG_DIR/profiles/nixos/$HOSTNAME/disk.nix${RESET}"
  disko --mode destroy "$CONFIG_DIR/profiles/nixos/$HOSTNAME/disk.nix"

  echo -e "\n"
  echo -e "${GREEN}Running: ${WHITE}disko --mode format $CONFIG_DIR/profiles/nixos/$HOSTNAME/disk.nix${RESET}"
  disko --mode format "$CONFIG_DIR/profiles/nixos/$HOSTNAME/disk.nix"

  echo -e "${GREEN}Disk formatting completed successfully!${RESET}"
fi
