#!/usr/bin/env bash
set -euo pipefail

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

HOSTNAME="${1:-}"

if [[ "$HOSTNAME" = "" ]]; then
  echo -e "${RED}Run with ${WHITE}<HOSTNAME>${RED} argument (from ${WHITE}/nxconfig/profiles/nixos${RED})!${RESET}" >&2
  exit 1
fi

check_config_directory "nixos-create-sops-key" "bootstrap"

if [[ ! -e "$CONFIG_DIR/profiles/nixos/$HOSTNAME" ]]; then
  echo -e "${RED}Host ${WHITE}$HOSTNAME${RED} does not exist in ${WHITE}$CONFIG_DIR/profiles/nixos${RED}!${RESET}" >&2
  exit 1
fi

if [[ ! -e "$CONFIG_DIR/profiles/nixos/$HOSTNAME/$HOSTNAME.nix" ]]; then
  echo -e "${RED}Host ${WHITE}$HOSTNAME${RED} has no ${WHITE}$HOSTNAME.nix${RED} configuration in ${WHITE}$CONFIG_DIR/profiles/nixos${RED}!${RESET}" >&2
  exit 1
fi

echo -e "${GREEN}Evaluating configuration to find main user...${RESET}"
FULL_PROFILE="$(construct_profile_name "$HOSTNAME")"
USERNAME="$(nix eval --json --override-input config "path:$CONFIG_DIR" ".#hosts.$FULL_PROFILE.host.mainUser.username" 2>/dev/null || echo "null")"
if [[ -z "$USERNAME" || "$USERNAME" == "null" || "$USERNAME" == "\"null\"" ]]; then
  echo -e "${RED}Error: Could not determine main user from host configuration for ${WHITE}$HOSTNAME${RESET}" >&2
  echo -e "${RED}Make sure ${WHITE}mainUser${RED} is set in ${WHITE}$CONFIG_DIR/profiles/nixos/$HOSTNAME/$HOSTNAME.nix${RESET}" >&2
  exit 1
fi
USERNAME="${USERNAME//\"/}"

echo -e "${MAGENTA}You are about to create SOPS keys and prepare for NixOS installation for host ${WHITE}$HOSTNAME${GREEN} with admin user '${WHITE}$USERNAME${GREEN}'${RESET}"
read -p "Continue? [y|N]: " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo -e "\n"
  
  if ! mountpoint -q /mnt; then
    echo -e "${RED}Error: ${WHITE}/mnt${RED} is not mounted${RESET}" >&2
    echo -e "${RED}Please mount your target filesystem to ${WHITE}/mnt${RED} before creating SOPS keys${RESET}" >&2
    exit 1
  fi
  
  FULL_PROFILE_NAME="$(construct_profile_name "$HOSTNAME")"
  HOME="$(nix eval --json --override-input config "path:$CONFIG_DIR" ".#nixosConfigurations.$FULL_PROFILE_NAME.config.users.users.$USERNAME.home")"
  if [[ -z "$HOME" || "$HOME" == "null" ]]; then
    echo -e "${RED}Error: Failed to extract valid home directory for ${WHITE}$USERNAME${RESET}" >&2
    exit 1
  fi
  HOME="${HOME//\"/}"

  if [[ ! "$HOME" =~ ^/[a-zA-Z0-9_/.-]+$ ]]; then
    echo -e "${RED}Error: Invalid home directory path: ${WHITE}$HOME${RESET}" >&2
    exit 1
  fi

  USER_SOPS_DIR="/mnt/$HOME/.config/sops/age"
  
  if [[ -f "/mnt/etc/sops/age/keys.txt" && -f "$USER_SOPS_DIR/keys.txt" ]]; then
    echo -e "${GREEN}SOPS keys already exist, skipping creation.${RESET}"
  else
    if [[ ! -f "/mnt/etc/sops/age/keys.txt" ]]; then
      echo -e "${GREEN}Creating root SOPS key...${RESET}"
      mkdir -p "/mnt/etc/sops/age"
      age-keygen -o /mnt/etc/sops/age/keys.txt
      chmod 400 "/mnt/etc/sops/age/keys.txt"
      chown 0:0 "/mnt/etc/sops/age/keys.txt"
      echo -e "${GREEN}Root SOPS key created at ${WHITE}/mnt/etc/sops/age/keys.txt${RESET}"
    else
      echo -e "${GREEN}Root SOPS key already exists at ${WHITE}/mnt/etc/sops/age/keys.txt${RESET}"
    fi
    
    if [[ ! -f "$USER_SOPS_DIR/keys.txt" ]]; then
      echo -e "${GREEN}Installing user SOPS key for home-manager...${RESET}"
      
      mkdir -p "$USER_SOPS_DIR"
      mkdir -p "/mnt/$HOME/.config"
      
      cp "/mnt/etc/sops/age/keys.txt" "$USER_SOPS_DIR/keys.txt"
      
      chmod 400 "$USER_SOPS_DIR/keys.txt"
      
      echo -e "${GREEN}User SOPS key installed successfully at ${WHITE}$USER_SOPS_DIR/keys.txt${RESET}"

      echo -e "${GREEN}Fixing permissions of home folder now...${RESET}"
      USER_UID="$(nix eval --json --override-input config "path:$CONFIG_DIR" ".#nixosConfigurations.$FULL_PROFILE_NAME.config.users.users.$USERNAME.uid")"
      GROUP_NAME="$(nix eval --json --override-input config "path:$CONFIG_DIR" ".#nixosConfigurations.$FULL_PROFILE_NAME.config.users.users.$USERNAME.group")"

      if [[ -z "$USER_UID" || "$USER_UID" == "null" || -z "$GROUP_NAME" || "$GROUP_NAME" == "null" ]]; then
        echo -e "${RED}Error: Failed to extract valid user information for ${WHITE}$USERNAME${RESET}" >&2
        echo -e "${YELLOW}You might have to fix the permissions of /mnt/$HOME yourself before installing!${RESET}" >&2
      else
        USER_UID="${USER_UID//\"/}"
        GROUP_NAME="${GROUP_NAME//\"/}"
        
        USER_GID="$(nix eval --json --override-input config "path:$CONFIG_DIR" ".#nixosConfigurations.$FULL_PROFILE_NAME.config.users.groups.$GROUP_NAME.gid")"
        if [[ -z "$USER_GID" || "$USER_GID" == "null" ]]; then
          echo -e "${RED}Error: Failed to extract valid group GID for group ${WHITE}$GROUP_NAME${RESET}" >&2
          echo -e "${YELLOW}You might have to fix the permissions of /mnt/$HOME yourself before installing!${RESET}" >&2
        else
          USER_GID="${USER_GID//\"/}"
          chown "$USER_UID:$USER_GID" -R "/mnt/$HOME"
        fi
      fi
    else
      echo -e "${GREEN}User SOPS key already exists at ${WHITE}$USER_SOPS_DIR/keys.txt${RESET}"
    fi
  fi
  
  echo
  echo -e "${WHITE}🔑 Age public key:${RESET}"
  age-keygen -y /mnt/etc/sops/age/keys.txt
  
  echo
  echo -e "${GREEN}SOPS keys preparation completed successfully.${RESET}"
  echo
  echo -e "${MAGENTA}Next steps:${RESET}"
  echo -e "${MAGENTA}1. Re-encrypt the config directory with the new SOPS key.${RESET}"
  echo -e "${MAGENTA}2. Pull the updated config directory on this host.${RESET}"
  echo -e "${MAGENTA}3. You can then run ${WHITE}50-nixos-install.sh${MAGENTA} to proceed with the installation.${RESET}"
fi
