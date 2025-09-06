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

check_config_directory "mount" "bootstrap"

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

if mountpoint -q /mnt; then
  echo -e "${YELLOW}Warning: /mnt is already mounted${RESET}" >&2
  echo -e "Currently mounted:"
  mount | grep '/mnt'
  echo
  
  if [[ -e "/mnt/etc/NIXOS" ]]; then
    echo -e "${YELLOW}The mounted filesystem appears to contain a NixOS installation.${RESET}" >&2
    echo -e "${MAGENTA}Do you want to proceed with the existing mount?${RESET}"
    read -p "Continue? [Y|n]: " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
      echo -e "${GREEN}Proceeding with existing mount...${RESET}"
      exit 0
    fi
  fi
  
  echo -e "${MAGENTA}Do you want to unmount first?${RESET}"
  read -p "Continue? [y|N]: " -n 1 -r
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "\n"
    echo -e "${GREEN}Unmounting ${WHITE}/mnt${GREEN} recursively...${RESET}"
    umount -R /mnt || {
      echo -e "${RED}Failed to unmount ${WHITE}/mnt${RED}. Please unmount manually.${RESET}" >&2
      exit 1
    }
  else
    echo -e "\n${YELLOW}Aborting mount operation.${RESET}" >&2
    exit 1
  fi
fi

echo -e "Mounting existing filesystem from ${WHITE}$CONFIG_DIR/profiles/nixos/$HOSTNAME/disk.nix${RESET}"
echo -e "${GREEN}This will mount the existing partitions WITHOUT formatting or destroying data.${RESET}"
echo
echo -e "${MAGENTA}Do you want to proceed with mounting?${RESET}"
read -p "Continue? [y|N]: " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo -e "\n"
  echo -e "${GREEN}Running: ${WHITE}disko --mode mount $CONFIG_DIR/profiles/nixos/$HOSTNAME/disk.nix${RESET}"
  if disko --mode mount "$CONFIG_DIR/profiles/nixos/$HOSTNAME/disk.nix"; then
    echo
    echo -e "${GREEN}Filesystem mounted successfully!${RESET}"
    echo -e "${WHITE}Currently mounted:${RESET}"
    mount | grep '/mnt' || echo "  (no mounts found - this might indicate an error)"
  else
    echo -e "${RED}Failed to mount filesystem. Check disk configuration and ensure disks exist!${RESET}" >&2
    exit 1
  fi
else
  echo
  echo -e "${YELLOW}Mount operation cancelled.${RESET}"
fi
