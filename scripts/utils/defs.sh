#!/usr/bin/env bash

export RED='\033[1;31m'
export ORANGE='\033[38;5;208m'
export YELLOW='\033[1;33m'
export GREEN='\033[1;32m'
export WHITE='\033[1;37m'
export MAGENTA='\033[1;35m'
export BLUE='\033[1;34m'
export CYAN='\033[1;36m'
export GRAY='\033[1;90m'
export RESET='\033[0m'

export RAINBOW_COLOURS=(
  "${RED}"
  "${ORANGE}"
  "${YELLOW}"
  "${GREEN}"
  "${BLUE}"
  "${MAGENTA}"
)

export INFO_ICON="dialog-information"
export SUCCESS_ICON="nix-snowflake"
export ERROR_ICON="dialog-error"

export AUTO_UPDATE_INPUTS=(
    "nixpkgs"
    "nixpkgs-darwin"
    "nixpkgs-nix"
    "nixpkgs-unstable"
    "home-manager"
    "stylix"
    "nixvim"
    "nix-darwin"
    "sops-nix"
    "disko"
    "impermanence"
    "lanzaboote"
    "niri-flake"
    "nixos-hardware"
    "flake-parts"
    "flake-utils"
    "flake-compat"
    "nirimation"
    "solarized-everything-css"
    "nix-season-wallpaper"
)

export REBOOT_CHECK_INPUTS=(
    "nixpkgs"
    "nixpkgs-nix"
)

export TRUNCATE_INPUTS=(
    "nixpkgs-darwin"
    "nixpkgs-nix"
    "nixpkgs-unstable"
)

export THIRD_PARTY_INPUTS=(
    "mac-app-util"
    "nix-plist-manager"
)

export MODULES_ONLY_INPUTS=(
    "common"
    "linux"
    "darwin"
    "overlays"
    "themes"
    "groups"
)

export UPDATE_AUTO_MERGE_ENABLED=false
export UPDATE_MERGE_DAYS=(1 2 3 4 5 6 7)  # 1=Monday, 7=Sunday
