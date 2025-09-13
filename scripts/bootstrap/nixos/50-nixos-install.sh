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

check_config_directory "nixos-install" "bootstrap"

if [[ ! -e "$CONFIG_DIR/profiles/nixos/$HOSTNAME" ]]; then
  echo -e "${RED}Host ${WHITE}$HOSTNAME${RED} does not exist in ${WHITE}$CONFIG_DIR/profiles/nixos${RED}!${RESET}" >&2
  exit 1
fi

if [[ ! -e "$CONFIG_DIR/profiles/nixos/$HOSTNAME/$HOSTNAME.nix" ]]; then
  echo -e "${RED}Host ${WHITE}$HOSTNAME${RED} has no ${WHITE}$HOSTNAME.nix${RED} configuration in ${WHITE}$CONFIG_DIR/profiles/nixos${RED}!${RESET}" >&2
  exit 1
fi

FULL_PROFILE="$(construct_profile_name "$HOSTNAME")"
USERNAME="$(nix eval --json --override-input config "path:$CONFIG_DIR" ".#hosts.$FULL_PROFILE.host.mainUser.username" 2>/dev/null || echo "null")"
if [[ -z "$USERNAME" || "$USERNAME" == "null" || "$USERNAME" == "\"null\"" ]]; then
  echo -e "${RED}Error: Could not determine main user from host configuration for ${WHITE}$HOSTNAME${RESET}" >&2
  echo -e "${RED}Make sure ${WHITE}mainUser${RED} is set in ${WHITE}$CONFIG_DIR/profiles/nixos/$HOSTNAME/$HOSTNAME.nix${RESET}" >&2
  exit 1
fi
USERNAME="${USERNAME//\"/}"

echo -e "Using full profile name: ${WHITE}$FULL_PROFILE${RESET}"

HOME="$(nix eval --json --override-input config "path:$CONFIG_DIR" ".#nixosConfigurations.$FULL_PROFILE.config.users.users.$USERNAME.home")"
if [[ -z "$HOME" || "$HOME" == "null" ]]; then
  echo -e "${RED}Error: Failed to extract valid home directory for ${WHITE}$USERNAME${RESET}" >&2
  exit 1
fi
HOME="${HOME//\"/}"

if [[ ! "$HOME" =~ ^/[a-zA-Z0-9_/.-]+$ ]]; then
  echo -e "${RED}Error: Invalid home directory path: ${WHITE}$HOME${RESET}" >&2
  exit 1
fi

echo -e "${MAGENTA}You are about to install NixOS from profile ${WHITE}$CONFIG_DIR/profiles/nixos/$HOSTNAME/$HOSTNAME.nix${RESET} for admin user '${WHITE}$USERNAME${RESET}'"
read -p "Continue? [y|N]: " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
  echo -e "\n"
  
  if ! mountpoint -q /mnt; then
    echo -e "${RED}Error: ${WHITE}/mnt${RED} is not mounted${RESET}" >&2
    echo -e "${RED}Please mount your target filesystem to ${WHITE}/mnt${RED} before running nixos-install${RESET}" >&2
    exit 1
  fi
  
  if [[ ! -f "/mnt/etc/sops/age/keys.txt" ]]; then
    echo -e "${RED}Error: Root SOPS key not found at ${WHITE}/mnt/etc/sops/age/keys.txt${RESET}" >&2
    echo -e "${RED}Please run ${WHITE}scripts/bootstrap/nixos/30-nixos-create-sops-key.sh${RED} first to create SOPS keys${RESET}" >&2
    exit 1
  fi
  
  USER_SOPS_KEY="/mnt/$HOME/.config/sops/age/keys.txt"
  if [[ ! -f "$USER_SOPS_KEY" ]]; then
    echo -e "${RED}Error: User SOPS key not found at ${WHITE}$USER_SOPS_KEY${RESET}" >&2
    echo -e "${RED}Please run ${WHITE}scripts/bootstrap/nixos/30-nixos-create-sops-key.sh${RED} first to create SOPS keys${RESET}" >&2
    exit 1
  fi

  USER_UID="$(nix eval --json --override-input config "path:$CONFIG_DIR" ".#nixosConfigurations.$FULL_PROFILE.config.users.users.$USERNAME.uid")"
  GROUP_NAME="$(nix eval --json --override-input config "path:$CONFIG_DIR" ".#nixosConfigurations.$FULL_PROFILE.config.users.users.$USERNAME.group")"
  
  if [[ -z "$USER_UID" || "$USER_UID" == "null" || -z "$GROUP_NAME" || "$GROUP_NAME" == "null" ]]; then
    echo -e "${RED}Error: Failed to extract valid user information for ${WHITE}$USERNAME${RESET}" >&2
    exit 1
  fi

  USER_UID="${USER_UID//\"/}"
  GROUP_NAME="${GROUP_NAME//\"/}"
  
  USER_GID="$(nix eval --json --override-input config "path:$CONFIG_DIR" ".#nixosConfigurations.$FULL_PROFILE.config.users.groups.$GROUP_NAME.gid")"
  if [[ -z "$USER_GID" || "$USER_GID" == "null" ]]; then
    echo -e "${RED}Error: Failed to extract valid group GID for group ${WHITE}$GROUP_NAME${RESET}" >&2
    exit 1
  fi
  USER_GID="${USER_GID//\"/}"

  if [[ -e "/mnt/etc/NIXOS" ]]; then
    echo -e "${YELLOW}NixOS already appears to be installed on ${WHITE}/mnt${YELLOW} (found ${WHITE}/mnt/etc/NIXOS${YELLOW})" >&2
    echo -e "${YELLOW}Skipping nixos-install - system appears ready${RESET}" >&2
    echo -e "${YELLOW}If you need to reinstall, remove ${WHITE}/mnt/etc/NIXOS${YELLOW} first${RESET}" >&2
    NIXOS_ALREADY_INSTALLED=true
  else
    if [[ -d "/mnt/$HOME" ]]; then
      echo -e "Fixing general user dir permissions"
      chmod 700 "/mnt/$HOME"
      chown "$USER_UID:$USER_GID" -R "/mnt/$HOME"
    fi

    echo
    echo -e "Copying sops file temporarily to ${WHITE}/persist${RESET}"
    mkdir -p /mnt/persist/etc/sops/age
    cp -a /mnt/etc/sops/age/keys.txt /mnt/persist/etc/sops/age

    echo
    echo -e "Running: ${WHITE}nixos-install --flake .#$FULL_PROFILE --no-root-password --override-input config path:$CONFIG_DIR${RESET}"
    nixos-install --flake ".#$FULL_PROFILE" --no-root-password --override-input config "path:$CONFIG_DIR"

    if [ $? -ne 0 ]; then
      echo -e "${RED}Error: nixos-install failed! See above for error details.${RESET}" >&2
      exit 1
    fi

    echo -e "Clearing ${WHITE}/mnt/persist${RESET} directory for preparation of persistence"
    rm -rf /mnt/persist/* || true

    echo -e "${GREEN}NixOS installation completed successfully.${RESET}"
    NIXOS_ALREADY_INSTALLED=false
  fi

  BASE_DIR="/mnt/$HOME/.config/nx"
  CORE_DIR="/mnt/$HOME/.config/nx/nxcore"
  CONFIG_TARGET_DIR="/mnt/$HOME/.config/nx/nxconfig"
  
  if [[ -d "$CORE_DIR" && -f "$CORE_DIR/flake.nix" && -d "$CONFIG_TARGET_DIR" && -d "$CONFIG_TARGET_DIR/profiles" ]]; then
    echo -e "${GREEN}Both core and config directories appear to be already set up:${RESET}"
    echo -e "  - ${WHITE}$CORE_DIR${RESET} (has ${WHITE}flake.nix${RESET})"
    echo -e "  - ${WHITE}$CONFIG_TARGET_DIR${RESET} (has ${WHITE}profiles${RESET})"
    echo -e "${GREEN}Skipping configuration copying as setup appears complete.${RESET}"
  else
    if [[ -d "$CORE_DIR" ]]; then
      echo -e "${YELLOW}Warning: Core directory $CORE_DIR already exists${RESET}" >&2
      echo
      echo -e "${MAGENTA}Do you want to overwrite it?${RESET}"
      read -p "Continue? [y|N]: " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Aborting installation${RESET}" >&2
        exit 1
      fi
    fi

    echo -e "${WHITE}Copying core repository to target system...${RESET}"
    mkdir -p "/mnt/$HOME/.config/nx"
    cp -R --verbose -T . "$CORE_DIR"
    chown -R "$USER_UID:$USER_GID" "$CORE_DIR"
    
    echo -e "${WHITE}Copying config repository to target system...${RESET}"
    copy_config_to_target "$USERNAME" "$HOME" "$USER_UID" "$USER_GID"

    chown "$USER_UID:$USER_GID" "$BASE_DIR"
    chmod 700 "$CORE_DIR"
    chmod 700 "$CONFIG_TARGET_DIR"
    
    echo -e "${WHITE}Configuring git remotes for target system...${RESET}"
    configure_target_git_remotes "$HOME" "$USER_UID" "$USER_GID"
  fi

  echo
  echo -e "${WHITE}Checking if impermanence is enabled for this host...${RESET}"
  IMPERMANENCE_ENABLED="$(nix eval --json --override-input config "path:$CONFIG_DIR" ".#hosts.$FULL_PROFILE.host.impermanence" 2>/dev/null || echo "false")"
  
  echo
  echo -e "${MAGENTA}Next steps:${RESET}"
  if [[ "$IMPERMANENCE_ENABLED" == "true" ]]; then
    echo -e "${MAGENTA}  1) Run the script ${WHITE}60-migrate-to-persistence.sh${MAGENTA} (REQUIRED - impermanence is enabled)${RESET}"
    echo -e "${MAGENTA}  2) Reboot to enter the new host...${RESET}"
  else
    echo -e "${MAGENTA}  - Reboot to enter the new host...${RESET}"
    echo -e "${MAGENTA}    (No migration needed - impermanence is disabled)${RESET}"
  fi
fi
