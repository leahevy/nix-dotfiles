#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/common.sh"
simple_deployment_script_setup "configure-nix"

CHECK_ONLY=false

while [[ $# -gt 0 ]]; do
	case "${1:-}" in
	--check-only)
		CHECK_ONLY=true
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

NIX_DAEMON_FILE='/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
ZSHRC='/etc/zshrc'
NIX_BLOCK="
# Nix
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
. '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi
# End Nix"

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

DARWIN_TASKS=(configure_zshrc_darwin)
LINUX_TASKS=()

OS="$(uname -s)"

if [[ "$OS" == "Darwin" ]]; then
	PLATFORM_TASKS=("${DARWIN_TASKS[@]+"${DARWIN_TASKS[@]}"}")
elif [[ "$OS" == "Linux" ]]; then
	PLATFORM_TASKS=("${LINUX_TASKS[@]+"${LINUX_TASKS[@]}"}")
else
	PLATFORM_TASKS=()
fi

if [[ "${#PLATFORM_TASKS[@]}" -eq 0 ]]; then
	echo -e "${CYAN}Nothing to configure...${RESET}"
	exit 0
fi

for task in "${PLATFORM_TASKS[@]}"; do
	"$task"
done
