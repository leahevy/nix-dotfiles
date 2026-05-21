#!/usr/bin/env bash

export RED_LIGHT='\033[38;5;196m'
export ORANGE_LIGHT='\033[38;5;208m'
export YELLOW_LIGHT='\033[38;5;220m'
export GREEN_LIGHT='\033[38;5;82m'
export BLUE_LIGHT='\033[38;5;39m'
export MAGENTA_LIGHT='\033[38;5;201m'
export CYAN_LIGHT='\033[38;5;51m'
export GRAY_LIGHT='\033[38;5;250m'
export WHITE_LIGHT='\033[38;5;15m'

export RED_BOLD='\033[1;38;5;196m'
export ORANGE_BOLD='\033[1;38;5;208m'
export YELLOW_BOLD='\033[1;38;5;220m'
export GREEN_BOLD='\033[1;38;5;82m'
export BLUE_BOLD='\033[1;38;5;39m'
export MAGENTA_BOLD='\033[1;38;5;201m'
export CYAN_BOLD='\033[1;38;5;51m'
export GRAY_BOLD='\033[1;38;5;250m'
export WHITE_BOLD='\033[1;38;5;15m'

export RED="$RED_BOLD"
export ORANGE="$ORANGE_BOLD"
export YELLOW="$YELLOW_BOLD"
export GREEN="$GREEN_BOLD"
export BLUE="$BLUE_BOLD"
export MAGENTA="$MAGENTA_BOLD"
export CYAN="$CYAN_BOLD"
export GRAY="$GRAY_LIGHT"
export WHITE="$WHITE_LIGHT"

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

export HOME_MANAGER_BACKUP_EXT="nix-rebuild.backup"

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
	"nixos-anywhere"
	"niri-flake"
	"nixos-hardware"
	"flake-parts"
	"flake-utils"
	"flake-compat"
	"nix-index-database"
	"treefmt-nix"
	"nirimation"
	"solarized-everything-css"
	"nix-season-wallpaper"
)

export PACKAGES_TO_HIGHLIGHT=(
	niri
	firefox
	firefox-unwrapped
	thunderbird-latest-unwrapped
	spotify
	docker
	ungoogled-chromium
	google-chrome
	signal-desktop
	tor-browser
	neovim
	qutebrowser
	ente-desktop
	logseq
	appflowy
	beeper
	bitwarden
	discord
	easytag
	fluffychat
	heroic
	paperless-ngx
	home-assistant
	pihole
	lutris
	onlyoffice
	protonmail-desktop
	syncthing
	tmux
	todoist
	vlc
	xwayland
	steam
	ghostty
	waybar
	nwg-wrapper
	keyd
	sops
	plymouth
	keepassxc
	vscodium
	nvidia-settings
	ollama
	vimPlugins.obsidian-nvim
	vimPlugins.nvim-treesitter
	borgbackup
	smartmontools
	obsidian
)

export NIXPKGS_INPUTS=(
	"nixpkgs"
	"nixpkgs-darwin"
	"nixpkgs-nix"
	"nixpkgs-unstable"
)

export REBOOT_NORMAL_CHECK_INPUTS=(
	"nixpkgs"
)

export REBOOT_NIX_CHECK_INPUTS=(
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
export UPDATE_MERGE_DAYS=(1 2 3 4 5 6 7) # 1=Monday, 7=Sunday
