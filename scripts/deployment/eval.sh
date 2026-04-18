#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/common.sh"
deployment_script_setup "eval"
check_deployment_conflicts "eval"

HOME_MODE=false
override_profile=""
override_arch=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --home) HOME_MODE=true; shift ;;
    --profile)
      [[ $# -lt 2 ]] && { echo -e "${RED}Error: --profile requires a profile name${RESET}" >&2; exit 1; }
      override_profile="$2"
      shift 2
      ;;
    --arch)
      [[ $# -lt 2 ]] && { echo -e "${RED}Error: --arch requires an architecture${RESET}" >&2; exit 1; }
      override_arch="$2"
      shift 2
      ;;
    --nixos)
      force_nixos=true
      shift
      ;;
    --standalone)
      force_standalone=true
      shift
      ;;
    --*) echo -e "${RED}Unknown option ${WHITE}${1}${RESET}" >&2; exit 1 ;;
    *) break ;;
  esac
done

[[ "${force_nixos:-false}" == "true" && "${force_standalone:-false}" == "true" ]] && {
  echo -e "${RED}Error: --nixos and --standalone cannot be used together${RESET}" >&2
  exit 1
}

EVAL_PATH="${1:-}"

if [[ "$EVAL_PATH" == "" ]]; then
  echo -e "${RED}Eval path missing for flake evaluation!${RESET}" >&2
  exit 1
fi

base_profile=""
if [[ -n "$override_profile" ]]; then
  base_profile="$override_profile"
elif [[ -e .nx-profile.conf ]]; then
  base_profile="$(cat .nx-profile.conf)"
elif [[ "${force_nixos:-false}" == "true" ]] || [[ -e /etc/NIXOS ]]; then
  base_profile="$HOSTNAME"
else
  base_profile="$USER"
fi

PROFILE=""
if [[ -n "$override_arch" ]]; then
  PROFILE="$(construct_profile_name "$base_profile" "$override_arch")"
else
  PROFILE="$(construct_profile_name "$base_profile")"
fi

context=""
if [[ "${force_nixos:-false}" == "true" ]]; then
  context="nixos"
elif [[ "${force_standalone:-false}" == "true" ]]; then
  context="home"
elif [[ -e /etc/NIXOS ]]; then
  context="nixos"
else
  context="home"
fi

if [[ -n "$override_arch" ]]; then
  if [[ "$context" == "nixos" && ! "$override_arch" =~ -linux$ ]]; then
    echo -e "${RED}Error: NixOS profiles only support Linux architectures (x86_64-linux, aarch64-linux)${RESET}" >&2
    echo -e "${YELLOW}Hint: Use --profile to specify a home-manager profile, or use --standalone flag${RESET}" >&2
    exit 1
  fi
fi

if [[ "$context" == "nixos" ]]; then
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

EXTRA_ARGS=()
if [[ -n "${NXCORE_DIR:-}" && "${NX_DEPLOYMENT_MODE:-develop}" == "develop" ]]; then
    EXTRA_ARGS=("--override-input" "core" "path:$NXCORE_DIR")
fi

# shellcheck disable=SC2016
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
