#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/common.sh"
deployment_script_setup "sync"

parse_common_deployment_args "$@"
check_git_worktrees_clean

PROFILE="$(retrieve_active_profile)"

verify_commits
check_deployment_conflicts "sync"

if [[ -e /etc/NIXOS ]]; then
	if nh os switch --show-activation-logs -H "$PROFILE" . -- "${EXTRA_ARGS[@]:-}"; then
		notify_success "Sync"
	else
		notify_error "Sync"
		exit 1
	fi
else
	if GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null nh home switch --show-activation-logs . -c "$PROFILE" -b "$HOME_MANAGER_BACKUP_EXT" -- "${EXTRA_ARGS[@]:-}"; then
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
			echo -e "${YELLOW}Brewfile created, you should run: ${GREEN}nx brew${YELLOW} to sync Homebrew packages${RESET}"
		elif [[ -f "$BREWFILE_ACTIVE" ]]; then
			CHECKSUM_NEW=$(shasum -a 256 "$BREWFILE" | cut -d' ' -f1)
			CHECKSUM_ACTIVE=$(shasum -a 256 "$BREWFILE_ACTIVE" | cut -d' ' -f1)

			if [[ "$CHECKSUM_NEW" != "$CHECKSUM_ACTIVE" ]]; then
				echo
				echo -e "${YELLOW}Brewfile was updated, you should run: ${GREEN}nx brew${RESET}"
			else
				WEEK_AGO=$(date -v-7d +%s)
				LAST_BREW_RUN=$(stat -f %m "$BREWFILE_ACTIVE")
				if [[ "$LAST_BREW_RUN" -lt "$WEEK_AGO" ]]; then
					DAYS_AGO=$((($(date +%s) - LAST_BREW_RUN) / 86400))
					echo
					echo -e "${RED} > It's been ${BLUE}${DAYS_AGO} days${RED} since you last updated Homebrew - you should run ${GREEN}nx brew${RED}${RESET}"
				fi
			fi
		fi
	fi
fi
