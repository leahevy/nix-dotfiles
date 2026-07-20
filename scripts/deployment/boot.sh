#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/common.sh"
deployment_script_setup "boot"

parse_common_deployment_args "$@"
ensure_nixos_only "boot"
confirm_server_manual_deploy "boot"
verify_checked_out_branch "$NXCORE_DIR"
verify_checked_out_branch "$CONFIG_DIR"
require_repos_on_same_branch

check_git_worktrees_clean
verify_commits
check_deployment_conflicts "boot"

prompt_aide_pre_boot_check

PROFILE="$(retrieve_active_profile)"

if nh os boot --show-activation-logs -H "$PROFILE" . -- "${EXTRA_ARGS[@]:-}"; then
	notify_success "Boot"
else
	notify_error "Boot"
	exit 1
fi

mark_aide_post_boot_commit
