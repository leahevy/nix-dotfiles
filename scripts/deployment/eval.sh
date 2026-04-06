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
    FULL_EVAL_PATH="nixosConfigurations.${PROFILE}.config.${EVAL_PATH}"
  fi
else
  if [[ "$HOME_MODE" == "true" ]]; then
    echo -e "${RED}Option ${WHITE}--home${RED} is not available in standalone mode${RESET}" >&2
    exit 1
  fi
  FULL_EVAL_PATH="homeConfigurations.${PROFILE}.config.${EVAL_PATH}"
fi

EXTRA_ARGS=("--override-input" "config" "path:$CONFIG_DIR" "--override-input" "profile" "path:$PROFILE_PATH")

nix eval ".#${FULL_EVAL_PATH}" "${EXTRA_ARGS[@]}" --apply '
x: let
  lib = builtins;
  sanitize = v:
    if lib.isFunction v then "<function>"
    else if lib.isAttrs v then
      if v ? __functor then "<function>"
      else lib.mapAttrs (n: _: sanitize v.${n}) (lib.removeAttrs v ["_module"])
    else if lib.isList v then map sanitize v
    else v;
in sanitize x
' --json
