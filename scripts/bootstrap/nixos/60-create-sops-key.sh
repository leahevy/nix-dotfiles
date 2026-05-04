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

check_config_directory "create-sops-key" "bootstrap"
cd "$CONFIG_DIR"

GENERATE_STUB=false
HOSTNAME=""

while [[ $# -gt 0 ]]; do
	case "${1:-}" in
	--generate-stub)
		GENERATE_STUB=true
		shift
		;;
	-*)
		echo -e "${RED}Error: Unknown option ${WHITE}${1:-}${RESET}" >&2
		echo -e "${RED}Usage: ${WHITE}$0${RED} [--generate-stub] [HOSTNAME]${RESET}" >&2
		exit 1
		;;
	*)
		HOSTNAME="${1:-}"
		shift
		;;
	esac
done

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

echo -e "${GREEN}Evaluating configuration to find main user...${RESET}"
FULL_PROFILE="$(construct_profile_name "$HOSTNAME")"
USERNAME="$(nix eval --json --override-input core "path:$NXCORE_DIR" ".#nixosConfigurations.$FULL_PROFILE.config.nx.profile.host.mainUser.username" 2>/dev/null || echo "null")"
if [[ -z "$USERNAME" || "$USERNAME" == "null" || "$USERNAME" == "\"null\"" ]]; then
	echo -e "${RED}Error: Could not determine main user from host configuration for ${WHITE}$HOSTNAME${RESET}" >&2
	echo -e "${RED}Make sure ${WHITE}mainUser${RED} is set in ${WHITE}$CONFIG_DIR/profiles/nixos/$HOSTNAME/$HOSTNAME.nix${RESET}" >&2
	exit 1
fi
USERNAME="${USERNAME//\"/}"

echo -e "${YELLOW}You are about to create SOPS keys and prepare for NixOS installation for host ${WHITE}$HOSTNAME${GREEN} with admin user '${WHITE}$USERNAME${GREEN}'${RESET}"
read -p "Continue? [y|N]: " -n 1 -r
if [[ $REPLY =~ ^[Yy]$ ]]; then
	echo -e "\n"

	if ! mountpoint -q /mnt; then
		echo -e "${RED}Error: ${WHITE}/mnt${RED} is not mounted!${RESET}" >&2
		echo -e "${RED}Run ${WHITE}nx bootstrap nixos mount${RED} first to mount the target filesystem.${RESET}" >&2
		exit 1
	fi

	FULL_PROFILE_NAME="$(construct_profile_name "$HOSTNAME")"
	USER_HOME="$(nix eval --json --override-input core "path:$NXCORE_DIR" ".#nixosConfigurations.$FULL_PROFILE_NAME.config.users.users.$USERNAME.home")"
	if [[ -z "$USER_HOME" || "$USER_HOME" == "null" ]]; then
		echo -e "${RED}Error: Failed to extract valid home directory for ${WHITE}$USERNAME${RESET}" >&2
		exit 1
	fi
	USER_HOME="${USER_HOME//\"/}"

	if [[ ! "$USER_HOME" =~ ^/[a-zA-Z0-9_/.-]+$ ]]; then
		echo -e "${RED}Error: Invalid home directory path: ${WHITE}$USER_HOME${RESET}" >&2
		exit 1
	fi

	USER_SOPS_DIR="/mnt${USER_HOME}/.config/sops/age"
	ROOT_SOPS_KEY="/mnt/etc/sops/age/keys.txt"
	USER_SOPS_KEY="$USER_SOPS_DIR/keys.txt"
	STUB_KEY="AGE-SECRET-KEY-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"

	if [[ -f "$ROOT_SOPS_KEY" && -f "$USER_SOPS_KEY" ]]; then
		echo -e "${GREEN}SOPS keys already exist, skipping creation.${RESET}"
	else
		if [[ ! -f "$ROOT_SOPS_KEY" ]]; then
			if [[ "$GENERATE_STUB" == "true" ]]; then
				echo -e "${GREEN}Creating root SOPS key stub...${RESET}"
			else
				echo -e "${GREEN}Creating root SOPS key...${RESET}"
			fi
			mkdir -p "/mnt/etc/sops/age"
			if [[ "$GENERATE_STUB" == "true" ]]; then
				printf '%s\n' "$STUB_KEY" >"$ROOT_SOPS_KEY"
			else
				age-keygen -o "$ROOT_SOPS_KEY"
			fi
			chmod 400 "$ROOT_SOPS_KEY"
			chown 0:0 "$ROOT_SOPS_KEY"
			echo -e "${GREEN}Root SOPS key created at ${WHITE}$ROOT_SOPS_KEY${RESET}"
		else
			echo -e "${GREEN}Root SOPS key already exists at ${WHITE}$ROOT_SOPS_KEY${RESET}"
		fi

		if [[ ! -f "$USER_SOPS_KEY" ]]; then
			if [[ "$GENERATE_STUB" == "true" ]]; then
				echo -e "${GREEN}Creating user SOPS key stub for home-manager...${RESET}"
			else
				echo -e "${GREEN}Installing user SOPS key for home-manager...${RESET}"
			fi

			mkdir -p "$USER_SOPS_DIR"
			mkdir -p "/mnt${USER_HOME}/.config"

			cp "$ROOT_SOPS_KEY" "$USER_SOPS_KEY"

			chmod 400 "$USER_SOPS_KEY"

			echo -e "${GREEN}User SOPS key installed successfully at ${WHITE}$USER_SOPS_KEY${RESET}"

			echo -e "${GREEN}Fixing permissions of home folder now...${RESET}"
			USER_UID="$(nix eval --json --override-input core "path:$NXCORE_DIR" ".#nixosConfigurations.$FULL_PROFILE_NAME.config.users.users.$USERNAME.uid")"
			GROUP_NAME="$(nix eval --json --override-input core "path:$NXCORE_DIR" ".#nixosConfigurations.$FULL_PROFILE_NAME.config.users.users.$USERNAME.group")"

			if [[ -z "$USER_UID" || "$USER_UID" == "null" || -z "$GROUP_NAME" || "$GROUP_NAME" == "null" ]]; then
				echo -e "${RED}Error: Failed to extract valid user information for ${WHITE}$USERNAME${RESET}" >&2
				echo -e "${YELLOW}You might have to fix the permissions of /mnt${USER_HOME} yourself before installing!${RESET}" >&2
			else
				USER_UID="${USER_UID//\"/}"
				GROUP_NAME="${GROUP_NAME//\"/}"

				USER_GID="$(nix eval --json --override-input core "path:$NXCORE_DIR" ".#nixosConfigurations.$FULL_PROFILE_NAME.config.users.groups.$GROUP_NAME.gid")"
				if [[ -z "$USER_GID" || "$USER_GID" == "null" ]]; then
					echo -e "${RED}Error: Failed to extract valid group GID for group ${WHITE}$GROUP_NAME${RESET}" >&2
					echo -e "${YELLOW}You might have to fix the permissions of /mnt${USER_HOME} yourself before installing!${RESET}" >&2
				else
					USER_GID="${USER_GID//\"/}"
					chown "$USER_UID:$USER_GID" "$USER_SOPS_KEY" || true
					chown "$USER_UID:$USER_GID" -R "/mnt${USER_HOME}"
				fi
			fi
		else
			echo -e "${GREEN}User SOPS key already exists at ${WHITE}$USER_SOPS_KEY${RESET}"
		fi
	fi

	echo
	if [[ "$GENERATE_STUB" == "true" ]]; then
		echo -e "${GREEN}SOPS key stubs created successfully.${RESET}"
		echo
		echo -e "${YELLOW}Next steps:${RESET}"
		echo -e "${YELLOW}1. Edit both key files and replace the stub value with the real age secret keys.${RESET}"
		echo -e "${YELLOW}   ${WHITE}vim -p $ROOT_SOPS_KEY $USER_SOPS_KEY${RESET}"
		echo -e "${YELLOW}2. Re-encrypt the config directory with the new SOPS key(s).${RESET}"
		echo -e "${YELLOW}3. Pull the updated config directory on this host.${RESET}"
		echo -e "${YELLOW}4. You can then run ${WHITE}nx bootstrap nixos install${YELLOW} to proceed with the installation.${RESET}"
	else
		echo -e "${WHITE}🔑 Age public key:${RESET}"
		age-keygen -y "$ROOT_SOPS_KEY"

		echo
		echo -e "${GREEN}SOPS keys preparation completed successfully.${RESET}"
		echo
		echo -e "${YELLOW}Next steps:${RESET}"
		echo -e "${YELLOW}1. Re-encrypt the config directory with the new SOPS key.${RESET}"
		echo -e "${YELLOW}2. Pull the updated config directory on this host.${RESET}"
		echo -e "${YELLOW}3. You can then run ${WHITE}nx bootstrap nixos install${YELLOW} to proceed with the installation.${RESET}"
	fi
fi
