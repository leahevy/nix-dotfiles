#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/common.sh"
deployment_script_setup "rollback"

parse_minimal_deployment_args "$@"
ensure_nixos_only "rollback"

check_git_worktrees_clean
check_deployment_conflicts "rollback"

if nh os rollback "${EXTRA_ARGS[@]:-}"; then
	notify_success "Rollback"
else
	notify_error "Rollback"
	exit 1
fi
