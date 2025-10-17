#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
deployment_script_setup "rollback"

parse_minimal_deployment_args "$@"
ensure_nixos_only "rollback"

check_git_worktrees_clean
check_deployment_conflicts "rollback"

PROFILE="$(retrieve_active_profile)"

export_nixos_label

nh os rollback "${EXTRA_ARGS[@]:-}"
