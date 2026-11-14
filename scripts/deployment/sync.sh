#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/common.sh"
deployment_script_setup "sync"

parse_common_deployment_args "$@"
confirm_server_manual_deploy "sync"
verify_checked_out_branch "$NXCORE_DIR"
verify_checked_out_branch "$CONFIG_DIR"
require_repos_on_same_branch
check_git_worktrees_clean

PROFILE="$(retrieve_active_profile)"

verify_commits
check_deployment_conflicts "sync"

if [[ -e /etc/NIXOS ]]; then
	if [[ "$USE_HOME_MANAGER" == "true" ]]; then
		echo -e "${RED}Error: --use-home-manager is only supported for standalone Home Manager sync!${RESET}" >&2
		exit 1
	fi
	if nh os switch --show-activation-logs -H "$PROFILE" . -- "${EXTRA_ARGS[@]:-}"; then
		notify_success "Sync"
	else
		notify_error "Sync"
		exit 1
	fi
else
	if [[ "$USE_HOME_MANAGER" == "true" ]]; then
		if GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null home-manager switch --flake ".#$PROFILE" -b "$HOME_MANAGER_BACKUP_EXT" "${EXTRA_ARGS[@]:-}"; then
			notify_success "Sync"
		else
			notify_error "Sync"
			exit 1
		fi
	elif GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null nh home switch --show-activation-logs . -c "$PROFILE" -b "$HOME_MANAGER_BACKUP_EXT" -- "${EXTRA_ARGS[@]:-}"; then
		notify_success "Sync"
	else
		notify_error "Sync"
		exit 1
	fi
fi

if [[ "$(uname -s)" == "Darwin" ]]; then
	BREWFILE="$HOME/.local/state/homebrew/Brewfile"
	BREWFILE_ACTIVE="$HOME/.local/state/homebrew/Brewfile.active"

	if [[ -e "$BREWFILE" ]]; then
		if [[ ! -f "$BREWFILE_ACTIVE" ]]; then
			echo
			echo -e "${YELLOW}Brewfile created, you should run: ${GREEN}nx install${YELLOW} to sync Homebrew packages${RESET}"
		elif [[ -f "$BREWFILE_ACTIVE" ]]; then
			CHECKSUM_NEW=$(shasum -a 256 "$BREWFILE" | cut -d' ' -f1)
			CHECKSUM_ACTIVE=$(shasum -a 256 "$BREWFILE_ACTIVE" | cut -d' ' -f1)

			if [[ "$CHECKSUM_NEW" != "$CHECKSUM_ACTIVE" ]]; then
				echo
				echo -e "${YELLOW}Brewfile was updated, you should run: ${GREEN}nx install${RESET}"
			else
				WEEK_AGO=$(date -v-7d +%s)
				LAST_BREW_RUN=$(stat -f %m "$BREWFILE_ACTIVE")
				if [[ "$LAST_BREW_RUN" -lt "$WEEK_AGO" ]]; then
					DAYS_AGO=$((($(date +%s) - LAST_BREW_RUN) / 86400))
					echo
					echo -e "${RED} > It's been ${BLUE}${DAYS_AGO} days${RED} since you last updated Homebrew - you should run ${GREEN}nx install${RED}${RESET}"
				fi
			fi
		fi
	fi
fi

if [[ "$(uname -s)" == "Linux" && ! -e /etc/NIXOS ]]; then
	APT_HINTS="$HOME/.local/bin-nx/apt-hints"
	if [[ -x "$APT_HINTS" ]]; then
		APT_HINTS_OUTPUT="$("$APT_HINTS" 2>/dev/null || true)"
		if [[ -n "$APT_HINTS_OUTPUT" ]]; then
			echo
			echo -e "${YELLOW}Apt hints:${RESET}"
			echo "$APT_HINTS_OUTPUT"
		fi
	fi

	PKGFILE="$HOME/.local/state/apt/packages.list"
	PKGFILE_ACTIVE="$HOME/.local/state/apt/packages.active"

	if [[ -e "$PKGFILE" ]]; then
		if [[ ! -f "$PKGFILE_ACTIVE" ]]; then
			echo
			echo -e "${YELLOW}Package list created, run: ${GREEN}nx install${YELLOW} to install packages${RESET}"
		elif ! command diff -q "$PKGFILE" "$PKGFILE_ACTIVE" &>/dev/null; then
			echo
			echo -e "${YELLOW}Package list updated, run: ${GREEN}nx install${RESET}"
		else
			UPGRADABLE=0
			if command -v apt-get &>/dev/null; then
				UPGRADABLE=$(apt-get -s full-upgrade 2>/dev/null | grep -c "^Inst " || true)
			fi
			if [[ "${UPGRADABLE}" -gt 0 ]]; then
				echo
				echo -e "${YELLOW}${UPGRADABLE} package(s) can be upgraded, run: ${GREEN}nx install${RESET}"
			else
				WEEK_AGO=$(date -d "7 days ago" +%s)
				LAST_APT_RUN=$(stat -c %Y "$PKGFILE_ACTIVE")
				if [[ "$LAST_APT_RUN" -lt "$WEEK_AGO" ]]; then
					DAYS_AGO=$((($(date +%s) - LAST_APT_RUN) / 86400))
					echo
					echo -e "${RED} > It's been ${BLUE}${DAYS_AGO} days${RED} since you last ran nx install - you should run ${GREEN}nx install${RED}${RESET}"
				fi
			fi
		fi
	fi
fi

prompt_aide_commit "Sync"
