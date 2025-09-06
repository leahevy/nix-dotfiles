#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
deployment_script_setup "sync"
check_git_worktrees_clean

PROFILE="$(retrieve_active_profile)"

parse_common_deployment_args "$@"


if [[ -e /etc/NIXOS ]]; then
  export_nixos_label

  nh os switch -H "$PROFILE" . -- --impure "${EXTRA_ARGS[@]:-}"
else
  nh home switch ".#homeConfigurations.$PROFILE.activationPackage" -b nix-rebuild.backup -- --impure "${EXTRA_ARGS[@]:-}"
fi
