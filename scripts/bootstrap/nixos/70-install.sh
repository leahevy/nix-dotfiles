#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

REPO_ROOT="$(cd "$SCRIPT_DIR/../../../" && pwd)"
cd "$REPO_ROOT"

export BOOTSTRAP_NEEDS_NIX=true
source "$REPO_ROOT/scripts/utils/common.sh"

if [[ ! -e /etc/NIXOS ]]; then
	echo -e "${RED}Did not detect NixOS -> aborting installation...${RESET}" >&2
	exit 1
fi

if [[ "$UID" != 0 ]]; then
	echo -e "${RED}Requires root!${RESET}" >&2
	exit 1
fi

HOSTNAME="${1:-}"

check_config_directory "install" "bootstrap"
cd "$CONFIG_DIR"

: "${NXCORE_DIR:?}"

if [[ -z "$HOSTNAME" && -e ".nx-profile.conf" ]]; then
	HOSTNAME="$(cat .nx-profile.conf)"
	echo -e "Found base profile in ${WHITE}$PWD/.nx-profile.conf${RESET} file: ${WHITE}$HOSTNAME${RESET}" >&2
fi

if [[ -z "$HOSTNAME" ]]; then
	echo -e "${RED}Run with ${WHITE}<HOSTNAME>${RED} argument or run ${WHITE}nx bootstrap nixos select-profile <HOSTNAME>${RED} first!${RESET}" >&2
	exit 1
fi

if [[ ! -e "$CONFIG_DIR/profiles/nixos/$HOSTNAME" ]]; then
	echo -e "${RED}Host ${WHITE}$HOSTNAME${RED} does not exist in ${WHITE}$CONFIG_DIR/profiles/nixos${RED}!${RESET}" >&2
	exit 1
fi

if [[ ! -e "$CONFIG_DIR/profiles/nixos/$HOSTNAME/$HOSTNAME.nix" ]]; then
	echo -e "${RED}Host ${WHITE}$HOSTNAME${RED} has no ${WHITE}$HOSTNAME.nix${RED} configuration in ${WHITE}$CONFIG_DIR/profiles/nixos${RED}!${RESET}" >&2
	exit 1
fi

if ! mountpoint -q /mnt; then
	echo -e "${RED}Error: ${WHITE}/mnt${RED} is not mounted!${RESET}" >&2
	echo -e "${RED}Run ${WHITE}nx bootstrap nixos mount${RED} first to mount the target filesystem.${RESET}" >&2
	exit 1
fi

FULL_PROFILE="$(construct_profile_name "$HOSTNAME")"
USERNAME="$(nix eval --json --override-input core "path:$NXCORE_DIR" ".#nixosConfigurations.$FULL_PROFILE.config.nx.profile.host.mainUser.username" 2>/dev/null || echo "null")"
if [[ -z "$USERNAME" || "$USERNAME" == "null" || "$USERNAME" == "\"null\"" ]]; then
	echo -e "${RED}Error: Could not determine main user from host configuration for ${WHITE}$HOSTNAME${RESET}" >&2
	echo -e "${RED}Make sure ${WHITE}mainUser${RED} is set in ${WHITE}$CONFIG_DIR/profiles/nixos/$HOSTNAME/$HOSTNAME.nix${RESET}" >&2
	exit 1
fi
USERNAME="${USERNAME//\"/}"

echo -e "Using full profile name: ${WHITE}$FULL_PROFILE${RESET}"

PERSIST_PATH=$(nix eval --raw --override-input core "path:$NXCORE_DIR" .#variables.persist)

SYSTEM_PERSISTED=0
if [[ -n "${PERSIST_PATH:-}" && "$PERSIST_PATH" != "/" && -e "/mnt${PERSIST_PATH}/etc/IMPERMANENCE" ]]; then
	SYSTEM_PERSISTED=1
fi

echo
echo -e "${WHITE}Checking if impermanence is enabled for this host...${RESET}"
IMPERMANENCE_ENABLED="$(nix eval --json --override-input core "path:$NXCORE_DIR" ".#nixosConfigurations.$FULL_PROFILE.config.nx.profile.host.impermanence" 2>/dev/null || echo "false")"

USER_HOME="$(nix eval --json --override-input core "path:$NXCORE_DIR" ".#nixosConfigurations.$FULL_PROFILE.config.users.users.$USERNAME.home")"
if [[ -z "$USER_HOME" || "$USER_HOME" == "null" ]]; then
	echo -e "${RED}Error: Failed to extract valid home directory for ${WHITE}$USERNAME${RESET}" >&2
	exit 1
fi
USER_HOME="${USER_HOME//\"/}"

if [[ ! "$USER_HOME" =~ ^/[a-zA-Z0-9_/.-]+$ ]]; then
	echo -e "${RED}Error: Invalid home directory path: ${WHITE}$USER_HOME${RESET}" >&2
	exit 1
fi

MNT_USER_HOME="/mnt$USER_HOME"
MNT_PERSIST_USER_HOME="/mnt${PERSIST_PATH}$USER_HOME"

echo -e "${YELLOW}You are about to install NixOS from profile ${WHITE}$CONFIG_DIR/profiles/nixos/$HOSTNAME/$HOSTNAME.nix${RESET} for admin user '${WHITE}$USERNAME${RESET}'"
read -p "Continue? [y|N]: " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
	echo -e "\n"

	if ! mountpoint -q /mnt; then
		echo -e "${RED}Error: ${WHITE}/mnt${RED} is not mounted!${RESET}" >&2
		echo -e "${RED}Run ${WHITE}nx bootstrap nixos mount${RED} first to mount the target filesystem.${RESET}" >&2
		exit 1
	fi

	ROOT_SOPS_KEY="/mnt/etc/sops/age/keys.txt"
	if [[ ! -f "$ROOT_SOPS_KEY" && "$SYSTEM_PERSISTED" == "1" ]]; then
		ROOT_SOPS_KEY="/mnt${PERSIST_PATH}/etc/sops/age/keys.txt"
	fi

	if [[ ! -f "$ROOT_SOPS_KEY" ]]; then
		echo -e "${RED}Error: Root SOPS key not found at ${WHITE}/mnt/etc/sops/age/keys.txt${RED} or ${WHITE}/mnt${PERSIST_PATH}/etc/sops/age/keys.txt${RESET}" >&2
		echo -e "${RED}Please run ${WHITE}nx bootstrap nixos create-sops-key${RED} first to create SOPS keys${RESET}" >&2
		exit 1
	fi

	if ! age-keygen -y "$ROOT_SOPS_KEY" >/dev/null 2>&1; then
		echo -e "${RED}Error: Root SOPS key at ${WHITE}$ROOT_SOPS_KEY${RED} is not a valid age key!${RESET}" >&2
		exit 1
	fi

	USER_SOPS_KEY="$MNT_USER_HOME/.config/sops/age/keys.txt"
	if [[ ! -f "$USER_SOPS_KEY" && "$SYSTEM_PERSISTED" == "1" ]]; then
		USER_SOPS_KEY="$MNT_PERSIST_USER_HOME/.config/sops/age/keys.txt"
	fi
	if [[ ! -f "$USER_SOPS_KEY" ]]; then
		echo -e "${RED}Error: User SOPS key not found at ${WHITE}$MNT_USER_HOME/.config/sops/age/keys.txt${RED} or ${WHITE}$MNT_PERSIST_USER_HOME/.config/sops/age/keys.txt${RESET}" >&2
		echo -e "${RED}Please run ${WHITE}nx bootstrap nixos create-sops-key${RED} first to create SOPS keys${RESET}" >&2
		exit 1
	fi

	if ! age-keygen -y "$USER_SOPS_KEY" >/dev/null 2>&1; then
		echo -e "${RED}Error: User SOPS key at ${WHITE}$USER_SOPS_KEY${RED} is not a valid age key!${RESET}" >&2
		exit 1
	fi

	USER_UID="$(nix eval --json --override-input core "path:$NXCORE_DIR" ".#nixosConfigurations.$FULL_PROFILE.config.users.users.$USERNAME.uid")"
	GROUP_NAME="$(nix eval --json --override-input core "path:$NXCORE_DIR" ".#nixosConfigurations.$FULL_PROFILE.config.users.users.$USERNAME.group")"

	if [[ -z "$USER_UID" || "$USER_UID" == "null" || -z "$GROUP_NAME" || "$GROUP_NAME" == "null" ]]; then
		echo -e "${RED}Error: Failed to extract valid user information for ${WHITE}$USERNAME${RESET}" >&2
		exit 1
	fi

	USER_UID="${USER_UID//\"/}"
	GROUP_NAME="${GROUP_NAME//\"/}"

	USER_GID="$(nix eval --json --override-input core "path:$NXCORE_DIR" ".#nixosConfigurations.$FULL_PROFILE.config.users.groups.$GROUP_NAME.gid")"
	if [[ -z "$USER_GID" || "$USER_GID" == "null" ]]; then
		echo -e "${RED}Error: Failed to extract valid group GID for group ${WHITE}$GROUP_NAME${RESET}" >&2
		exit 1
	fi
	USER_GID="${USER_GID//\"/}"

	if [[ -e "/mnt/etc/NIXOS" || -e "/mnt${PERSIST_PATH}/etc/NIXOS" ]]; then
		if [[ -e "/mnt/etc/NIXOS" ]]; then
			NIXOS_MARKER="/mnt/etc/NIXOS"
		else
			NIXOS_MARKER="/mnt${PERSIST_PATH}/etc/NIXOS"
		fi

		echo -e "${YELLOW}NixOS already appears to be installed on ${WHITE}/mnt${YELLOW} (found ${WHITE}$NIXOS_MARKER${YELLOW})" >&2
		echo -e "${YELLOW}Skipping nixos-install - system appears ready${RESET}" >&2
		echo -e "${YELLOW}If you need to reinstall, remove ${WHITE}$NIXOS_MARKER${YELLOW} first${RESET}" >&2
	else
		if [[ -d "/mnt/$USER_HOME" ]]; then
			echo -e "Fixing general user dir permissions"
			chmod 700 "/mnt/$USER_HOME"
			chown "$USER_UID:$USER_GID" -R "/mnt/$USER_HOME"
		fi

		echo
		echo -e "Copying sops file temporarily to ${WHITE}$PERSIST_PATH${RESET}"
		mkdir -p /mnt"${PERSIST_PATH}"/etc/sops/age
		cp -a "$ROOT_SOPS_KEY" /mnt"${PERSIST_PATH}"/etc/sops/age/keys.txt

		echo
		echo -e "Running: ${WHITE}nixos-install --flake .#$FULL_PROFILE --no-root-password --override-input core path:$NXCORE_DIR${RESET}"
		if ! nixos-install --flake ".#$FULL_PROFILE" --no-root-password --override-input core "path:$NXCORE_DIR"; then
			echo -e "${RED}Error: nixos-install failed! See above for error details.${RESET}" >&2
			exit 1
		fi

		echo
		echo -e "${GREEN}Installation succeeded.${RESET}"
		echo
		echo -e "${WHITE}Press enter to continue...${RESET}"
		read -r

		if [[ -z "${PERSIST_PATH:-}" || "$PERSIST_PATH" == "/" ]]; then
			echo -e "${RED}Error: Refusing to clear invalid persistence path: ${WHITE}${PERSIST_PATH:-<empty>}${RESET}" >&2
			exit 1
		fi

		echo -e "Clearing ${WHITE}/mnt${PERSIST_PATH}${RESET} directory for preparation of persistence"
		rm -rf "/mnt${PERSIST_PATH:?}/"* || true

		echo -e "${GREEN}NixOS installation completed successfully.${RESET}"
	fi

	BASE_DIR="$MNT_USER_HOME/.config/nx"
	CORE_DIR="$BASE_DIR/nxcore"
	CONFIG_TARGET_DIR="$BASE_DIR/nxconfig"

	PERSIST_BASE_DIR="$MNT_PERSIST_USER_HOME/.config/nx"
	PERSIST_CORE_DIR="$PERSIST_BASE_DIR/nxcore"
	PERSIST_CONFIG_TARGET_DIR="$PERSIST_BASE_DIR/nxconfig"

	if [[ "$SYSTEM_PERSISTED" == "1" ]]; then
		if [[ -d "$PERSIST_CORE_DIR" && -f "$PERSIST_CORE_DIR/flake.nix" && -d "$PERSIST_CONFIG_TARGET_DIR" && -d "$PERSIST_CONFIG_TARGET_DIR/profiles" ]]; then
			BASE_DIR="$PERSIST_BASE_DIR"
			CORE_DIR="$PERSIST_CORE_DIR"
			CONFIG_TARGET_DIR="$PERSIST_CONFIG_TARGET_DIR"
		fi
	fi

	if [[ -d "$CORE_DIR" && -f "$CORE_DIR/flake.nix" && -d "$CONFIG_TARGET_DIR" && -d "$CONFIG_TARGET_DIR/profiles" ]]; then
		echo -e "${GREEN}Both core and config directories appear to be already set up:${RESET}"
		echo -e "  - ${WHITE}$CORE_DIR${RESET} (has ${WHITE}flake.nix${RESET})"
		echo -e "  - ${WHITE}$CONFIG_TARGET_DIR${RESET} (has ${WHITE}profiles${RESET})"
		echo
		echo -e "${GREEN}Skipping repository copy.${RESET}"
		echo
		echo -e "${WHITE}Ensuring git remotes are configured for target system...${RESET}"
		configure_target_git_remotes "$USER_HOME" "$USER_UID" "$USER_GID"
	else
		if [[ -d "$CORE_DIR" ]]; then
			echo -e "${YELLOW}Warning: Core directory $CORE_DIR already exists${RESET}" >&2
			echo
			echo -e "${YELLOW}Do you want to overwrite it?${RESET}"
			read -p "Continue? [y|N]: " -n 1 -r
			echo
			if [[ ! $REPLY =~ ^[Yy]$ ]]; then
				echo -e "${RED}Aborting installation${RESET}" >&2
				exit 1
			fi
		fi

		echo -e "${WHITE}Copying core repository to target system...${RESET}"
		mkdir -p "/mnt/$USER_HOME/.config/nx"
		cp -R --verbose -T "$NXCORE_DIR" "$CORE_DIR"
		chown -R "$USER_UID:$USER_GID" "$CORE_DIR"

		echo -e "${WHITE}Copying config repository to target system...${RESET}"
		copy_config_to_target "$USER_HOME" "$USER_UID" "$USER_GID"

		chown "$USER_UID:$USER_GID" "$BASE_DIR"
		chmod 700 "$CORE_DIR"
		chmod 700 "$CONFIG_TARGET_DIR"

		echo -e "${WHITE}Configuring git remotes for target system...${RESET}"
		configure_target_git_remotes "$USER_HOME" "$USER_UID" "$USER_GID"
	fi

	echo
	echo -e "${YELLOW}Next steps:${RESET}"
	if [[ "$IMPERMANENCE_ENABLED" == "true" ]]; then
		echo -e "${YELLOW}  1) Run ${WHITE}nx bootstrap nixos migrate-to-persistence${YELLOW} (REQUIRED - impermanence is enabled)${RESET}"
		echo -e "${YELLOW}  2) Reboot to enter the new host...${RESET}"
	else
		echo -e "${YELLOW}  - Reboot to enter the new host...${RESET}"
		echo -e "${YELLOW}    (No migration needed - impermanence is disabled)${RESET}"
	fi
fi
