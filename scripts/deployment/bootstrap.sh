#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/defs.sh"

BOOTSTRAP_DIR_NIXOS="$SCRIPT_DIR/../bootstrap/nixos"
BOOTSTRAP_DIR_STANDALONE="$SCRIPT_DIR/../bootstrap/standalone"

show_list() {
	echo -e "${CYAN}Available bootstrap scripts:${RESET}"
	echo
	echo -e "${WHITE}nixos:${RESET}"
	echo -e "   ${WHITE}decrypt${RESET}                   00-decrypt.sh"
	echo -e "   ${WHITE}fetch-latest-config${RESET}       10-fetch-latest-config.sh"
	echo -e "   ${WHITE}disk-format${RESET} <hostname>    20-disk-format.sh"
	echo -e "   ${WHITE}mount${RESET} <hostname>          30-mount.sh"
	echo -e "   ${WHITE}create-profile-stub${RESET} [hostname] [--no-root]  40-create-profile-stub.sh"
	echo -e "   ${WHITE}nixos-create-sops-key${RESET} <hostname>  50-nixos-create-sops-key.sh"
	echo -e "   ${WHITE}nixos-install${RESET} <hostname>  60-nixos-install.sh"
	echo -e "   ${WHITE}migrate-to-persistence${RESET} <hostname> [--dry-run]  70-migrate-to-persistence.sh"
	echo
	echo -e "${WHITE}standalone:${RESET}"
	echo -e "   ${WHITE}nix-installation${RESET}          00-nix-installation.sh"
	echo -e "   ${WHITE}create-sops-key${RESET}           10-create-sops-key.sh"
	echo -e "   ${WHITE}initial-sync${RESET}              20-initial-sync.sh"
}

if [[ -n "${NX_INSTALL_PATH:-}" ]]; then
	echo -e "${YELLOW}Warning: Bootstrap scripts cannot be executed from an installed system.${RESET}" >&2
	echo -e "${YELLOW}They must be run from a NixOS live ISO or a standalone pre-install environment.${RESET}" >&2
	echo
	show_list
	exit 0
fi

SUBCOMMAND="${1:-}"
shift || true

if [[ -z "$SUBCOMMAND" ]]; then
	show_list
	exit 0
fi

SCRIPT_NAME="${1:-}"
shift || true

case "$SUBCOMMAND" in
nixos)
	if [[ -e /etc/NIXOS ]]; then
		echo -e "${RED}Error: NixOS is already installed on this system.${RESET}" >&2
		echo -e "${RED}Bootstrap scripts are for fresh installations only.${RESET}" >&2
		exit 1
	fi

	if [[ "$(uname -s)" == "Darwin" ]]; then
		echo -e "${RED}Error: Use './nx bootstrap standalone' on MacOS.${RESET}" >&2
		exit 1
	fi

	if [[ -z "$SCRIPT_NAME" ]]; then
		echo -e "${CYAN}Available nixos bootstrap scripts:${RESET}"
		echo -e "   ${WHITE}decrypt${RESET}                   00-decrypt.sh"
		echo -e "   ${WHITE}fetch-latest-config${RESET}       10-fetch-latest-config.sh"
		echo -e "   ${WHITE}disk-format${RESET} <hostname>    20-disk-format.sh"
		echo -e "   ${WHITE}mount${RESET} <hostname>          30-mount.sh"
		echo -e "   ${WHITE}create-profile-stub${RESET} [hostname] [--no-root]  40-create-profile-stub.sh"
		echo -e "   ${WHITE}nixos-create-sops-key${RESET} <hostname>  50-nixos-create-sops-key.sh"
		echo -e "   ${WHITE}nixos-install${RESET} <hostname>  60-nixos-install.sh"
		echo -e "   ${WHITE}migrate-to-persistence${RESET} <hostname> [--dry-run]  70-migrate-to-persistence.sh"
		exit 0
	fi

	case "$SCRIPT_NAME" in
	decrypt) SCRIPT_FILE="00-decrypt.sh" ;;
	fetch-latest-config) SCRIPT_FILE="10-fetch-latest-config.sh" ;;
	disk-format) SCRIPT_FILE="20-disk-format.sh" ;;
	mount) SCRIPT_FILE="30-mount.sh" ;;
	create-profile-stub) SCRIPT_FILE="40-create-profile-stub.sh" ;;
	nixos-create-sops-key) SCRIPT_FILE="50-nixos-create-sops-key.sh" ;;
	nixos-install) SCRIPT_FILE="60-nixos-install.sh" ;;
	migrate-to-persistence) SCRIPT_FILE="70-migrate-to-persistence.sh" ;;
	*)
		echo -e "${RED}Error: Unknown nixos bootstrap script: ${WHITE}$SCRIPT_NAME${RESET}" >&2
		exit 1
		;;
	esac
	BOOTSTRAP_DIR="$BOOTSTRAP_DIR_NIXOS"
	;;
standalone)
	if [[ -e /etc/NIXOS ]]; then
		echo -e "${RED}Error: Use './nx bootstrap nixos' on NixOS.${RESET}" >&2
		exit 1
	fi

	if [[ -z "$SCRIPT_NAME" ]]; then
		echo -e "${CYAN}Available standalone bootstrap scripts:${RESET}"
		echo -e "   ${WHITE}nix-installation${RESET}          00-nix-installation.sh"
		echo -e "   ${WHITE}create-sops-key${RESET}           10-create-sops-key.sh"
		echo -e "   ${WHITE}initial-sync${RESET}              20-initial-sync.sh"
		exit 0
	fi

	case "$SCRIPT_NAME" in
	nix-installation)
		if [[ -d /nix/store ]]; then
			echo -e "${RED}Error: /nix/store already exists - Nix appears to be installed already.${RESET}" >&2
			exit 1
		fi
		SCRIPT_FILE="00-nix-installation.sh"
		;;
	create-sops-key)
		if [[ ! -d /nix/store ]]; then
			echo -e "${RED}Error: /nix/store not found - run ${WHITE}nix-installation${RED} first.${RESET}" >&2
			exit 1
		fi
		SCRIPT_FILE="10-create-sops-key.sh"
		;;
	initial-sync)
		if [[ ! -d /nix/store ]]; then
			echo -e "${RED}Error: /nix/store not found - run ${WHITE}nix-installation${RED} first.${RESET}" >&2
			exit 1
		fi
		SCRIPT_FILE="20-initial-sync.sh"
		;;
	*)
		echo -e "${RED}Error: Unknown standalone bootstrap script: ${WHITE}$SCRIPT_NAME${RESET}" >&2
		exit 1
		;;
	esac
	BOOTSTRAP_DIR="$BOOTSTRAP_DIR_STANDALONE"
	;;
*)
	echo -e "${RED}Error: Unknown bootstrap type: ${WHITE}$SUBCOMMAND${RESET}" >&2
	echo -e "Use ${WHITE}nixos${RESET} or ${WHITE}standalone${RESET}." >&2
	exit 1
	;;
esac

FULL_SCRIPT_PATH="$BOOTSTRAP_DIR/$SCRIPT_FILE"

if [[ ! -f "$FULL_SCRIPT_PATH" ]]; then
	echo -e "${RED}Error: Bootstrap script not found: ${WHITE}$FULL_SCRIPT_PATH${RESET}" >&2
	exit 1
fi

echo -e "${YELLOW}You are about to run bootstrap script:${RESET}"
echo -e "  ${WHITE}$SUBCOMMAND${RESET} / ${WHITE}$SCRIPT_FILE${RESET}"
if [[ $# -gt 0 ]]; then
	echo -e "  args: ${WHITE}$*${RESET}"
fi
echo
read -p "Continue? [y|N]: " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
	echo -e "${YELLOW}Aborted.${RESET}"
	exit 0
fi

exec bash "$FULL_SCRIPT_PATH" "$@"
