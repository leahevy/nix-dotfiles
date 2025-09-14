#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
deployment_script_setup "eval"

PROFILE="$(retrieve_active_profile)"
PROFILE_PATH="$(retrieve_active_profile_path)"

EVAL_PATH="${1:-}"

if [[ "$EVAL_PATH" == "" ]]; then
  echo "Eval path missing for flake evaluation!" >&2
  exit 1
fi

EXTRA_ARGS=("--override-input" "config" "path:$CONFIG_DIR" "--override-input" "profile" "path:$PROFILE_PATH")

nix eval ".#${EVAL_PATH}" "${EXTRA_ARGS[@]}"
