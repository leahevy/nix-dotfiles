#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
deployment_script_setup "boot"

parse_common_deployment_args "$@"
ensure_nixos_only "boot"

check_git_worktrees_clean

PROFILE="$(retrieve_active_profile)"

export_nixos_label

nh os boot -H "$PROFILE" . -- --impure "${EXTRA_ARGS[@]:-}"
