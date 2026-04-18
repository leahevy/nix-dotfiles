#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/common.sh"
deployment_script_setup "build-test"

PROFILE="$(retrieve_active_profile)"

parse_build_deployment_args "$@"
verify_commits
check_deployment_conflicts "build"

LOG_FORMAT=""
if [[ "${RAW_LOG:-false}" == "true" ]]; then
  LOG_FORMAT="--log-format internal-json"
fi

base_profile=""
if [[ -n "${BUILD_OVERRIDE_PROFILE:-}" ]]; then
  base_profile="$BUILD_OVERRIDE_PROFILE"
else
  base_profile="${PROFILE%--*}"
fi

if [[ -n "${BUILD_OVERRIDE_ARCH:-}" ]]; then
  PROFILE="$(construct_profile_name "$base_profile" "$BUILD_OVERRIDE_ARCH")"
elif [[ -n "${BUILD_OVERRIDE_PROFILE:-}" ]]; then
  PROFILE="$(construct_profile_name "$base_profile")"
fi

context=""
if [[ "${BUILD_FORCE_NIXOS:-false}" == "true" ]]; then
  context="nixos"
elif [[ "${BUILD_FORCE_STANDALONE:-false}" == "true" ]]; then
  context="home"
elif [[ -e /etc/NIXOS ]]; then
  context="nixos"
else
  context="home"
fi

if [[ "$context" == "nixos" ]]; then
  # shellcheck disable=SC2086
  NEW_SYSTEM=$(timeout "${TIMEOUT}s" nix build --no-link $DRY_RUN $LOG_FORMAT ".#nixosConfigurations.$PROFILE.config.system.build.toplevel" "${EXTRA_ARGS[@]:-}" --print-build-logs --print-out-paths)

  if [[ "${BUILD_HAS_OVERRIDE:-false}" == "true" ]]; then
    echo
    echo -e "${CYAN}Built derivation:${RESET} $NEW_SYSTEM"
  elif [[ "${BUILD_DIFF:-false}" == "true" ]]; then
    echo -e "${CYAN}Comparing new build with current active system...${RESET}"
    echo
    echo -e "${GREEN}=== Store Path Diff ===${RESET}"
    diff_store_paths /run/current-system "$NEW_SYSTEM" || echo -e "${YELLOW}Store path diff failed${RESET}"
    echo
    echo -e "${GREEN}=== Package Diff ===${RESET}"
    nvd --color=always --version-highlight=xmas diff /run/current-system "$NEW_SYSTEM"
  fi
else
  # shellcheck disable=SC2086
  NEW_HOME=$(GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null timeout "${TIMEOUT}s" nix build --no-link $DRY_RUN $LOG_FORMAT ".#homeConfigurations.$PROFILE.activationPackage" "${EXTRA_ARGS[@]:-}" --print-build-logs --print-out-paths)

  if [[ "${BUILD_HAS_OVERRIDE:-false}" == "true" ]]; then
    echo
    echo -e "${CYAN}Built derivation:${RESET} $NEW_HOME"
  elif [[ "${BUILD_DIFF:-false}" == "true" ]]; then
    echo -e "${CYAN}Comparing new build with current active home configuration...${RESET}"
    CURRENT_HOME=$(readlink -f ~/.local/state/nix/profiles/home-manager)
    echo
    echo -e "${GREEN}=== Store Path Diff ===${RESET}"
    diff_store_paths "$CURRENT_HOME" "$NEW_HOME" || echo -e "${YELLOW}Store path diff failed${RESET}"
    echo
    echo -e "${GREEN}=== Package Diff ===${RESET}"
    nvd --color=always --version-highlight=xmas diff "$CURRENT_HOME" "$NEW_HOME"
  fi
fi
