#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
deployment_script_setup "commit"

COMMIT_MESSAGE="${1:-}"
shift 1 || true

if [[ "$COMMIT_MESSAGE" == "" ]]; then
  echo -e "${RED}Commit message is missing: Usage: ${WHITE}<COMMIT_MESSAGE>${RESET}" >&2
  exit 1
fi

if [[ "${1:-}" != "" ]]; then
  echo -e "${RED}Additional argument given: Usage: ${WHITE}<COMMIT_MESSAGE>${RESET}" >&2
  exit 1
fi

echo -e "${GREEN}Commit files in main repository ${WHITE}(.config/nx/nxcore)${RESET}..."
git commit -m "$COMMIT_MESSAGE" || true

if [[ -d "$CONFIG_DIR/.git" ]]; then
    echo
    echo -e "${GREEN}Commit files in config repository ${WHITE}(.config/nx/nxconfig)${RESET}..."
    (cd "$CONFIG_DIR" && git commit -m "$COMMIT_MESSAGE" || true)
else
    echo
    echo -e "${YELLOW}Warning: Config directory does not exist or is no directory.${RESET}"
fi
