#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
deployment_script_setup "eval"
check_deployment_conflicts "eval"

PROFILE="$(retrieve_active_profile)"
PROFILE_PATH="$(retrieve_active_profile_path)"

HOME_MODE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --home) HOME_MODE=true; shift ;;
    --*) echo -e "${RED}Unknown option ${WHITE}${1}${RESET}" >&2; exit 1 ;;
    *) break ;;
  esac
done

EVAL_PATH="${1:-}"

if [[ "$EVAL_PATH" == "" ]]; then
  echo -e "${RED}Eval path missing for flake evaluation!${RESET}" >&2
  exit 1
fi

if [[ -e /etc/NIXOS ]]; then
  if [[ "$HOME_MODE" == "true" ]]; then
    MAIN_USER="$(get_main_username)"
    FULL_EVAL_PATH="nixosConfigurations.${PROFILE}.config.home-manager.users.${MAIN_USER}.${EVAL_PATH}"
  else
    FULL_EVAL_PATH="nixosConfigurations.${PROFILE}.${EVAL_PATH}"
  fi
else
  FULL_EVAL_PATH="homeConfigurations.${PROFILE}.${EVAL_PATH}"
fi

EXTRA_ARGS=("--override-input" "config" "path:$CONFIG_DIR" "--override-input" "profile" "path:$PROFILE_PATH" "--json")

nix eval ".#${FULL_EVAL_PATH}" "${EXTRA_ARGS[@]}"
