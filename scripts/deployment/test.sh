#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/common.sh"
deployment_script_setup "test"

parse_common_deployment_args "$@"
ensure_nixos_only "test"
check_deployment_conflicts "test"

PROFILE="$(retrieve_active_profile)"

if nh os test -H "$PROFILE" . -- "${EXTRA_ARGS[@]:-}"; then
  notify_success "Test"
else
  notify_error "Test"
  exit 1
fi
