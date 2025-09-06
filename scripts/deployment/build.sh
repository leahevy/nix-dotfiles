#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
deployment_script_setup "build-test"

PROFILE="$(retrieve_active_profile)"

parse_build_deployment_args "$@"

if [[ -e /etc/NIXOS ]]; then
  timeout "${TIMEOUT}s" nix build --no-link --impure $DRY_RUN ".#nixosConfigurations.$PROFILE.config.system.build.toplevel" "${EXTRA_ARGS[@]:-}"
else
  timeout "${TIMEOUT}s" nix build --no-link --impure $DRY_RUN ".#homeConfigurations.$PROFILE.activationPackage" "${EXTRA_ARGS[@]:-}"
fi
