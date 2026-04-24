#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/common.sh"
deployment_script_setup "boot"

parse_common_deployment_args "$@"
ensure_nixos_only "boot"

check_git_worktrees_clean
verify_commits
check_deployment_conflicts "boot"

PROFILE="$(retrieve_active_profile)"

if nh os boot -H "$PROFILE" . -- "${EXTRA_ARGS[@]:-}"; then
  notify_success "Boot"
else
  notify_error "Boot"
  exit 1
fi
