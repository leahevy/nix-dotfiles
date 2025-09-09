#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
deployment_script_setup "commit"
parse_git_args "$@"

if [[ ${#EXTRA_ARGS[@]:-} -eq 0 ]]; then
  echo -e "${RED}Commit message is missing: Usage: ${WHITE}<COMMIT_MESSAGE>${RESET}" >&2
  exit 1
fi

COMMIT_MESSAGE="${EXTRA_ARGS[0]}"

if [[ "$COMMIT_MESSAGE" =~ ^- ]]; then
  echo -e "${RED}Commit message cannot start with dash. Usage: ${WHITE}\"<COMMIT_MESSAGE>\"${RESET}" >&2
  exit 1
fi

if [[ ${#EXTRA_ARGS[@]:-} -gt 1 ]]; then
  echo -e "${RED}Additional argument given: Usage: ${WHITE}<COMMIT_MESSAGE>${RESET}" >&2
  exit 1
fi

if [[ "$ONLY_CONFIG" != true ]]; then
    echo -e "${GREEN}Commit files in main repository ${WHITE}(.config/nx/nxcore)${RESET}..."
    git commit -m "$COMMIT_MESSAGE" || true
fi

if [[ "$ONLY_CORE" != true ]] && [[ -d "$CONFIG_DIR/.git" ]]; then
    if [[ "$ONLY_CONFIG" != true ]]; then
        echo
    fi
    echo -e "${GREEN}Commit files in config repository ${WHITE}(.config/nx/nxconfig)${RESET}..."
    (cd "$CONFIG_DIR" && git commit -m "$COMMIT_MESSAGE" || true)
elif [[ "$ONLY_CORE" != true ]] && [[ "$ONLY_CONFIG" != true ]]; then
    echo
    echo -e "${YELLOW}Warning: Config directory does not exist or is no directory.${RESET}"
fi
