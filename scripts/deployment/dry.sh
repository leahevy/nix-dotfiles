#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/common.sh"
deployment_script_setup "dry"

parse_common_deployment_args "$@"
ensure_nixos_only "dry"
check_deployment_conflicts "dry"

PROFILE="$(retrieve_active_profile)"

nh os switch --dry -H "$PROFILE" . -- "${EXTRA_ARGS[@]:-}"
