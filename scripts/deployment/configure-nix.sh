#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/common.sh"
simple_deployment_script_setup "configure-nix"

CHECK_ONLY=false
UPGRADE=false

while [[ $# -gt 0 ]]; do
	case "${1:-}" in
	--check-only)
		CHECK_ONLY=true
		shift
		;;
	--upgrade)
		UPGRADE=true
		shift
		;;
	-*)
		echo -e "${RED}Unknown option ${WHITE}${1:-}${RESET}" >&2
		exit 1
		;;
	*)
		echo -e "${RED}Unknown argument ${WHITE}${1:-}${RESET}" >&2
		exit 1
		;;
	esac
done

OS="$(uname -s)"

if [[ "$UPGRADE" == "true" ]]; then
	if [[ "$OS" != "Darwin" ]]; then
		echo -e "${RED}--upgrade is only supported on Darwin${RESET}" >&2
		exit 1
	fi
	if [[ ! -d /nix/var/nix/profiles/default ]]; then
		echo -e "${RED}Nix profile not found: ${WHITE}/nix/var/nix/profiles/default${RESET}" >&2
		exit 1
	fi
	echo -e "${CYAN}Upgrading Nix via ${WHITE}/nix/var/nix/profiles/default${RESET}"
	sudo nix upgrade-nix --profile /nix/var/nix/profiles/default
	echo

	echo -e "${CYAN}Restarting Nix daemon...${RESET}"
	sudo launchctl kickstart -k system/org.nixos.nix-daemon
	exit
fi

NIX_DAEMON_FILE='/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
ZSHRC='/etc/zshrc'
NIX_BLOCK="
# Nix
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
. '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi
# End Nix"

NX_CONF='/etc/nix/nix.conf'

DESIRED_NIX_CONF_KEYS=(
	"experimental-features:nix-command flakes"
	"http-connections:15"
	"max-substitution-jobs:3"
	"connect-timeout:60"
	"stalled-download-timeout:120"
	"download-speed:3051"
	"http2:false"
	"keep-outputs:true"
	"keep-derivations:true"
	"allow-import-from-derivation:false"
	"auto-optimise-store:true"
)

get_nix_conf_value() {
	local key="$1"
	grep -E "^\s*${key}\s*=" "$NX_CONF" 2>/dev/null | tail -1 | sed 's/^[^=]*=//' | sed 's/^ *//' | sed 's/ *$//' || true
}

sed_inplace() {
	if [[ "$OS" == "Darwin" ]]; then
		sudo sed -i '' "$@"
	else
		sudo sed -i "$@"
	fi
}

configure_zshrc_darwin() {
	if [[ ! -f "$NIX_DAEMON_FILE" ]]; then
		echo -e "${RED}Nix daemon profile not found: ${WHITE}${NIX_DAEMON_FILE}${RESET}" >&2
		exit 1
	fi

	if grep -qF '# End Nix' "$ZSHRC" 2>/dev/null; then
		echo -e "${GREEN}${ZSHRC}: already configured${RESET}"
		return 0
	fi

	echo -e "${YELLOW}${ZSHRC}: needs Nix block${RESET}"

	if [[ "$CHECK_ONLY" == "true" ]]; then
		return 0
	fi

	read -r -p "Append Nix block to ${ZSHRC}? [y/N] " confirm
	if [[ "${confirm:-}" != "y" && "${confirm:-}" != "Y" ]]; then
		echo -e "${YELLOW}Aborted.${RESET}"
		exit 0
	fi

	printf '\n%s\n' "$NIX_BLOCK" | sudo tee -a "$ZSHRC" >/dev/null

	if ! grep -qF '# End Nix' "$ZSHRC" 2>/dev/null; then
		echo -e "${RED}Write verification failed. Check file manually: ${WHITE}${ZSHRC}${RESET}" >&2
		exit 1
	fi

	echo -e "${GREEN}Done. Reboot now.${RESET}"
}

configure_nix_conf() {
	if [[ ! -f "$NX_CONF" ]]; then
		echo -e "${YELLOW}${NX_CONF}: not found, skipping${RESET}"
		return 0
	fi

	if [[ -L "$NX_CONF" ]]; then
		echo -e "${RED}${NX_CONF} is a symlink; not modifying a managed config${RESET}" >&2
		exit 1
	fi

	local changes=()
	local current desired key entry

	for entry in "${DESIRED_NIX_CONF_KEYS[@]}"; do
		key="${entry%%:*}"
		desired="${entry#*:}"
		current="$(get_nix_conf_value "$key")"

		if [[ "$current" != "$desired" ]]; then
			if [[ -z "$current" ]]; then
				changes+=("${key}: <not set> -> ${desired}")
			else
				changes+=("${key}: ${current} -> ${desired}")
			fi
		fi
	done

	if [[ "${#changes[@]}" -eq 0 ]]; then
		echo -e "${GREEN}${NX_CONF}: already configured${RESET}"
		return 0
	fi

	echo -e "${YELLOW}${NX_CONF}: ${#changes[@]} setting(s) need updating:${RESET}"
	for change in "${changes[@]}"; do
		echo -e "  ${WHITE}${change}${RESET}"
	done

	if [[ "$CHECK_ONLY" == "true" ]]; then
		return 0
	fi

	read -r -p "Apply these changes to ${NX_CONF}? [y/N] " confirm
	if [[ "${confirm:-}" != "y" && "${confirm:-}" != "Y" ]]; then
		echo -e "${YELLOW}Aborted.${RESET}"
		exit 0
	fi

	for entry in "${DESIRED_NIX_CONF_KEYS[@]}"; do
		key="${entry%%:*}"
		desired="${entry#*:}"
		current="$(get_nix_conf_value "$key")"

		if [[ "$current" == "$desired" ]]; then
			continue
		fi

		if grep -qE "^\s*${key}\s*=" "$NX_CONF" 2>/dev/null; then
			sed_inplace "s|^\s*${key}\s*=.*|${key} = ${desired}|" "$NX_CONF"
		else
			printf '%s = %s\n' "$key" "$desired" | sudo tee -a "$NX_CONF" >/dev/null
		fi
	done

	echo -e "${GREEN}Done. Restart the Nix daemon to apply:${RESET}"
	if [[ "$OS" == "Darwin" ]]; then
		echo -e "  ${WHITE}sudo launchctl kickstart -k system/org.nixos.nix-daemon${RESET}"
		echo -e "  ${CYAN}(If the daemon was never started: ${WHITE}sudo launchctl bootstrap system /Library/LaunchDaemons/org.nixos.nix-daemon.plist${CYAN})${RESET}"
	else
		echo -e "  ${WHITE}sudo systemctl restart nix-daemon${RESET}"
	fi
}

DARWIN_OS_TASKS=(configure_zshrc_darwin)
LINUX_OS_TASKS=()

NIXOS_TYPE_TASKS=()
ALL_STANDALONE_TYPE_TASKS=(configure_nix_conf)

TYPE="standalone"
if [[ "$OS" == "Linux" ]] && [[ -e "/etc/NIXOS" ]]; then
	TYPE="nixos"
fi

PLATFORM_TASKS=()

if [[ "$OS" == "Darwin" ]] && [[ "${#DARWIN_OS_TASKS[@]}" -gt 0 ]]; then
	PLATFORM_TASKS+=("${DARWIN_OS_TASKS[@]}")
elif [[ "$OS" == "Linux" ]] && [[ "${#LINUX_OS_TASKS[@]}" -gt 0 ]]; then
	PLATFORM_TASKS+=("${LINUX_OS_TASKS[@]}")
fi

if [[ "$TYPE" == "standalone" ]] && [[ "${#ALL_STANDALONE_TYPE_TASKS[@]}" -gt 0 ]]; then
	PLATFORM_TASKS+=("${ALL_STANDALONE_TYPE_TASKS[@]}")
elif [[ "$TYPE" == "nixos" ]] && [[ "${#NIXOS_TYPE_TASKS[@]}" -gt 0 ]]; then
	PLATFORM_TASKS+=("${NIXOS_TYPE_TASKS[@]}")
fi

if [[ "${#PLATFORM_TASKS[@]}" -eq 0 ]]; then
	echo -e "${CYAN}Nothing to configure...${RESET}"
	exit 0
fi

total="${#PLATFORM_TASKS[@]}"
idx=0
for task in "${PLATFORM_TASKS[@]}"; do
	idx=$((idx + 1))
	if [[ "$idx" -gt 1 ]]; then
		echo
	fi
	echo -e "${GREEN}${idx}/${total}${RESET} ${WHITE}${task//_/ }${RESET}"
	"$task"
done
