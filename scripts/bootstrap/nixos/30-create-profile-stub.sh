#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REPO_ROOT="$(cd "$SCRIPT_DIR/../../../" && pwd)"

export BOOTSTRAP_NEEDS_NIX=true
source "$REPO_ROOT/scripts/utils/pre-check.sh"

if [[ ! -e /etc/NIXOS ]]; then
  echo -e "${RED}Did not detect NixOS -> aborting installation...${RESET}" >&2
  exit 1
fi

check_config_directory "create-profile-stub" "bootstrap"

HOSTNAME=""
NO_ROOT=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --no-root)
      NO_ROOT=true
      shift
      ;;
    *)
      if [[ -z "$HOSTNAME" ]]; then
        HOSTNAME="$1"
      else
        echo -e "${RED}Error: Unknown argument: ${WHITE}$1${RESET}" >&2
        echo -e "Usage: ${WHITE}$0${RESET} [HOSTNAME] [--no-root]" >&2
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$HOSTNAME" ]]; then
  DETECTED_HOSTNAME="$(hostname)"
  echo -e "${YELLOW}No hostname provided.${RESET}"
  echo -e "${MAGENTA}Use detected hostname '${WHITE}$DETECTED_HOSTNAME${MAGENTA}'?${RESET}"
  read -p "Continue? [y|N]: " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    HOSTNAME="$DETECTED_HOSTNAME"
  else
    echo -e "${RED}Hostname is required. Please provide it as an argument.${RESET}" >&2
    exit 1
  fi
fi

if [[ ! "$HOSTNAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  echo -e "${RED}Error: Invalid hostname. Use only alphanumeric characters, hyphens, and underscores.${RESET}" >&2
  exit 1
fi

PROFILE_DIR="$CONFIG_DIR/profiles/nixos/$HOSTNAME"
OVERWRITE_PROFILE=true
if [[ -d "$PROFILE_DIR" ]]; then
  echo -e "${YELLOW}Warning: Profile directory $PROFILE_DIR already exists!${RESET}" >&2
  echo -e "${MAGENTA}Do you want to overwrite it?${RESET}"
  read -p "Continue? [y|N]: " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    OVERWRITE_PROFILE=false
    echo -e "${YELLOW}Using existing profile without overwriting.${RESET}" >&2
  fi
fi

TEMP_DIR=$(mktemp -d)
HARDWARE_CONFIG="$TEMP_DIR/hardware-config.nix"
EVAL_WRAPPER="$TEMP_DIR/eval-hardware.nix"

cleanup() {
  rm -rf "$TEMP_DIR"
}
trap cleanup EXIT ERR

if [[ "$OVERWRITE_PROFILE" == "true" ]]; then
  echo -e "${GREEN}Generating hardware configuration...${RESET}"

  if [[ "$NO_ROOT" == "true" ]]; then
    echo -e "${GREEN}Running: ${WHITE}nixos-generate-config --show-hardware-config${RESET}"
    sudo nixos-generate-config --show-hardware-config > "$HARDWARE_CONFIG"
  else
    echo -e "${GREEN}Running: ${WHITE}nixos-generate-config --show-hardware-config --root /mnt${RESET}"
    if ! mountpoint -q /mnt; then
      echo -e "${RED}Error: ${WHITE}/mnt${RED} is not mounted. Use ${WHITE}--no-root${RED} to generate config for current system.${RESET}" >&2
      exit 1
    fi
    sudo nixos-generate-config --show-hardware-config --root /mnt > "$HARDWARE_CONFIG"
  fi

  if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: ${WHITE}jq${RED} is not available. Please make sure you're using the nixconfig live ISO.${RESET}" >&2
    exit 1
  fi

  echo -e "${GREEN}Parsing hardware configuration...${RESET}"

    cat > "$EVAL_WRAPPER" << 'EOF'
let
  hardware = import /tmp/nixconfig-hardware-config.nix;
  lib = (import <nixpkgs> {}).lib;
  pkgs = import <nixpkgs> {};
  modulesPath = <nixpkgs/nixos/modules>;
  
  dummyConfig = {
    boot = {};
    fileSystems = {};
    swapDevices = [];
    networking = {};
    nixpkgs = {};
  };
  
  result = hardware {
    config = dummyConfig;
    inherit lib pkgs modulesPath;
  };
  
in {
  bootModules = result.boot.initrd.availableKernelModules or [];
  initrdModules = result.boot.initrd.kernelModules or [];
  nixModules = result.boot.kernelModules or [];
  extraModulePackages = result.boot.extraModulePackages or [];
  hostPlatform = result.nixpkgs.hostPlatform or null;
  hardwareSettings = builtins.removeAttrs result ["boot" "fileSystems" "swapDevices" "networking" "nixpkgs" "hardware" "imports" ];
}
EOF

  cp "$HARDWARE_CONFIG" /tmp/nixconfig-hardware-config.nix

  echo -e "${WHITE}Extracting hardware information...${RESET}"
  if ! HARDWARE_JSON=$(cd "$REPO_ROOT" && nix eval --json --impure -f "$EVAL_WRAPPER" 2>/dev/null); then
    echo -e "${RED}Error: Failed to parse hardware configuration. The generated config may be invalid.${RESET}" >&2
    echo -e "Hardware config location: ${WHITE}$HARDWARE_CONFIG${RESET}" >&2
    exit 1
  fi

  BOOT_MODULES=$(echo "$HARDWARE_JSON" | jq -r '.bootModules[]' 2>/dev/null | sed 's/^/        "/' | sed 's/$/"/' || true)
  INITRD_MODULES=$(echo "$HARDWARE_JSON" | jq -r '.initrdModules[]' 2>/dev/null | sed 's/^/        "/' | sed 's/$/"/' || true)
  NIX_MODULES=$(echo "$HARDWARE_JSON" | jq -r '.nixModules[]' 2>/dev/null | sed 's/^/        "/' | sed 's/$/"/' || true)
  EXTRA_MODULE_PACKAGES=$(echo "$HARDWARE_JSON" | jq -r '.extraModulePackages[]' 2>/dev/null | sed 's/^/        "/' | sed 's/$/"/' || true)

  HARDWARE_SETTINGS="$(grep hardware. "$HARDWARE_CONFIG")"

  extract_unfree_packages() {
    if [[ -f "$HARDWARE_CONFIG" ]]; then
      grep -o 'allowUnfreePredicate.*\[.*\]' "$HARDWARE_CONFIG" 2>/dev/null | \
      sed -n 's/.*\[\s*\([^]]*\)\s*\].*/\1/p' | \
      tr ',' '\n' | \
      sed 's/^[[:space:]]*"*\([^"]*\)"*[[:space:]]*$/\1/' | \
      grep -v '^[[:space:]]*$' | \
      sort -u || true
    fi
  }

  UNFREE_PACKAGES=$(extract_unfree_packages)

  rm -f /tmp/nixconfig-hardware-config.nix

  if echo "$HARDWARE_JSON" | jq -e '.hardwareSettings.hardware' >/dev/null 2>&1; then
    extract_hardware_settings "hardware" ".hardwareSettings.hardware"
  fi

  echo -e "Creating profile directory: ${WHITE}$PROFILE_DIR${RESET}"
  mkdir -p "$PROFILE_DIR"

  echo -e "Generating ${WHITE}$HOSTNAME.nix${RESET}..."
  cat > "$PROFILE_DIR/$HOSTNAME.nix" << EOF
{ lib, ... }:

{
  config.host = {
    hostname = "$HOSTNAME";

    ethernetDeviceName = null;

    wifiDeviceName = null;

    additionalPackages = [ ];

    nixHardwareModule = null;

    mainUser = null;

    additionalUsers = [ ];

    extraGroupsToCreate = [ ];

    userDefaults = {
      groups = [ ];
      modules = { };
    };

    stateVersion = null;

    allowedUnfreePackages = [ ];

    kernel = {
      variant = "lts";
EOF

if [[ -n "$BOOT_MODULES" ]]; then
    cat >> "$PROFILE_DIR/$HOSTNAME.nix" << EOF
      bootModules = [
$BOOT_MODULES
      ];
EOF
else
    cat >> "$PROFILE_DIR/$HOSTNAME.nix" << EOF
      bootModules = [ ];
EOF
fi

if [[ -n "$INITRD_MODULES" ]]; then
    cat >> "$PROFILE_DIR/$HOSTNAME.nix" << EOF
      initrdModules = [
$INITRD_MODULES
      ];
EOF
else
    cat >> "$PROFILE_DIR/$HOSTNAME.nix" << EOF
      initrdModules = [ ];
EOF
fi

if [[ -n "$NIX_MODULES" ]]; then
    cat >> "$PROFILE_DIR/$HOSTNAME.nix" << EOF
      nixModules = [
$NIX_MODULES
      ];
EOF
else
    cat >> "$PROFILE_DIR/$HOSTNAME.nix" << EOF
      nixModules = [ ];
EOF
fi

if [[ -n "$EXTRA_MODULE_PACKAGES" ]]; then
    cat >> "$PROFILE_DIR/$HOSTNAME.nix" << EOF
      extraModulePackages = [
$EXTRA_MODULE_PACKAGES
      ];
EOF
else
    cat >> "$PROFILE_DIR/$HOSTNAME.nix" << EOF
      extraModulePackages = [ ];
EOF
fi

    cat >> "$PROFILE_DIR/$HOSTNAME.nix" << EOF
    };

    modules = {
      core = { };

      groups = {
        base = [
          "nixos"
        ];
      };

      config = { };
    };

    specialisations = { };

    defaultSpecialisation = "Base";

    settings = {
      networking = {
        wifi = {
          enabled = false;
        };
        useNetworkManager = true;
      };

      system = {
        tmpSize = "2G";
        timezone = "Europe/Berlin";
        locale = {
          main = "en_GB.UTF-8";
          extra = "de_DE.UTF-8";
        };
        keymap = {
          x11 = {
            layout = "us";
            variant = "";
          };
          console = "us";
        };
        sound = {
          pulse = {
            enabled = true;
          };
        };
        printing = {
          enabled = false;
        };
        touchpad = {
          enabled = false;
        };
        desktop = {
          gnome = {
            enabled = true;
          };
        };
      };

      sshd = {
        authorizedKeys = [ ];
      };
    };

    impermanence = false;

    extraSettings = { };

    configuration = args@{
      lib,
      pkgs,
      pkgs-unstable,
      funcs,
      helpers,
      defs,
      self,
      ...
    }: context@{ config, options, ... }: {
EOF

  if [[ -n "$HARDWARE_SETTINGS" ]]; then
    echo -e "$HARDWARE_SETTINGS" | sed 's/^/      /' >> "$PROFILE_DIR/$HOSTNAME.nix"
  fi

  cat >> "$PROFILE_DIR/$HOSTNAME.nix" << EOF
    };
  };
}
EOF

  chmod 644 "$PROFILE_DIR/$HOSTNAME.nix"
  
  chown -R nixos:users "$PROFILE_DIR"

  echo
  echo -e "${GREEN}Profile stub generated successfully!${RESET}"
  echo -e "Location: ${WHITE}$PROFILE_DIR/${RESET}"
  echo -e "${GREEN}Files created:${RESET}"
  echo -e "   - ${WHITE}$HOSTNAME.nix${RESET} (main configuration with hardware settings)"

  if [[ -n "$UNFREE_PACKAGES" ]]; then
    echo
    echo -e "${YELLOW}Required unfree packages detected${RESET}:"
    echo "$UNFREE_PACKAGES" | sed 's/^/     - /'
    echo
    echo -e "${YELLOW}Add these to ${WHITE}variables.nix${YELLOW}: allowedUnfreePackages:${RESET}"
    echo -e "${WHITE}  allowedUnfreePackages = [${RESET}"
    echo "$UNFREE_PACKAGES" | sed 's/^/    "/' | sed 's/$/"/'
    echo -e "${WHITE}  ];${RESET}"
  fi
else
  echo
  echo -e "Using existing profile at ${WHITE}$PROFILE_DIR/${RESET}"
  echo -e "${YELLOW}Skipped hardware configuration regeneration.${RESET}"
fi

echo
echo -e "${MAGENTA}Next steps:${RESET}"
echo -e "${MAGENTA}   1. Edit ${WHITE}$PROFILE_DIR/$HOSTNAME.nix${MAGENTA} to set ${WHITE}mainUser${MAGENTA}, ${WHITE}additionalUsers${MAGENTA}, and ${WHITE}ethernetDeviceName${RESET}"
echo -e "${MAGENTA}   2. Configure modules and settings as needed${RESET}"
echo -e "${MAGENTA}   3. Run bootstrap scripts: ${WHITE}40-nixos-create-sops-key.sh${MAGENTA} then ${WHITE}50-nixos-install.sh${RESET} and if needed ${WHITE}50-migrate-to-persistence.sh${RESET}"
