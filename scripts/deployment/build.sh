#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
deployment_script_setup "build-test"

PROFILE="$(retrieve_active_profile)"

parse_build_deployment_args "$@"
verify_commits

if [[ -e /etc/NIXOS ]]; then
  NEW_SYSTEM=$(timeout "${TIMEOUT}s" nix build --no-link --impure $DRY_RUN ".#nixosConfigurations.$PROFILE.config.system.build.toplevel" "${EXTRA_ARGS[@]:-}" --print-out-paths)

  if [[ "${BUILD_DIFF:-false}" == "true" ]]; then
    echo -e "${CYAN}Comparing new build with current active system...${RESET}"
    echo
    echo -e "${GREEN}=== Closure Diff ===${RESET}"
    nix store diff-closures /run/current-system "$NEW_SYSTEM"
    echo
    echo -e "${GREEN}=== nvd Diff ===${RESET}"
    nvd --color=always --version-highlight=xmas diff /run/current-system "$NEW_SYSTEM"
  fi
else
  NEW_HOME=$(timeout "${TIMEOUT}s" nix build --no-link --impure $DRY_RUN ".#homeConfigurations.$PROFILE.activationPackage" "${EXTRA_ARGS[@]:-}" --print-out-paths)

  if [[ "${BUILD_DIFF:-false}" == "true" ]]; then
    echo -e "${CYAN}Comparing new build with current active home configuration...${RESET}"
    CURRENT_HOME=$(readlink -f ~/.local/state/nix/profiles/home-manager)
    echo
    echo -e "${GREEN}=== Closure Diff ===${RESET}"
    nix store diff-closures "$CURRENT_HOME" "$NEW_HOME"
    echo
    echo -e "${GREEN}=== nvd Diff ===${RESET}"
    nvd --color=always --version-highlight=xmas diff "$CURRENT_HOME" "$NEW_HOME"
  fi
fi
