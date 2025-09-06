#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
simple_deployment_script_setup "profile"

PROFILE_NAME="${1:-}"

if [[ "$PROFILE_NAME" = "--reset" ]]; then
  if [[ -f .nx-profile.conf ]]; then
    rm .nx-profile.conf
    echo -e "${GREEN}Profile configuration reset - using default profile${RESET}"
  else
    echo -e "${YELLOW}No profile configuration found to reset${RESET}"
  fi
  exit 0
fi

if [[ "$PROFILE_NAME" =~ ^- ]]; then
  echo -e "${RED}Unknown option: ${WHITE}$PROFILE_NAME${RESET}" >&2
  echo -e "${RED}Expected: ${WHITE}<PROFILE_NAME>${RED} or ${WHITE}--reset${RESET}" >&2
  exit 1
fi

if [[ "$PROFILE_NAME" = "" ]]; then
  echo -e "${RED}Expected: ${WHITE}<PROFILE_NAME>${RED} or ${WHITE}--reset${RESET}" >&2
  exit 1
fi

echo -n "$PROFILE_NAME" > .nx-profile.conf
echo -e "${GREEN}Profile set to: ${WHITE}$PROFILE_NAME${RESET}"
