#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
deployment_script_setup "package"
check_deployment_conflicts "package"

UNSTABLE=false
PACKAGES=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --unstable)
      UNSTABLE=true
      shift
      ;;
    -*)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
    *)
      PACKAGES+=("$1")
      shift
      ;;
  esac
done

if [[ ${#PACKAGES[@]} -eq 0 ]]; then
  echo "No packages specified!" >&2
  exit 1
fi

NIXPKGS_INPUT="nixpkgs"
if [[ "$UNSTABLE" == "true" ]]; then
  NIXPKGS_INPUT="nixpkgs-unstable"
fi

ARCHITECTURE="$(detect_system_architecture)"

HAS_ERRORS=false

for PACKAGE in "${PACKAGES[@]}"; do
  EVAL_PATH="${NIXPKGS_INPUT}.legacyPackages.${ARCHITECTURE}.${PACKAGE}.drvPath"

  if DRV_PATH=$(nix eval ".#${EVAL_PATH}" --raw 2>/dev/null); then
    if STORE_PATH=$(nix-store -q --outputs "$DRV_PATH" 2>/dev/null); then
      echo "$STORE_PATH"
    else
      echo "Error: Failed to get store path for package '$PACKAGE'" >&2
      HAS_ERRORS=true
    fi
  else
    echo "Error: Package '$PACKAGE' not found in $NIXPKGS_INPUT" >&2
    HAS_ERRORS=true
  fi
done

if [[ "$HAS_ERRORS" == "true" ]]; then
  exit 1
fi