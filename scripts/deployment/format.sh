#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/common.sh"
deployment_script_setup "format"

if [[ -n "${NXCORE_DIR:-}" && -d "$NXCORE_DIR/.git" ]]; then
    cd "$NXCORE_DIR"
    echo -e "${GREEN}Formatting main repository ${WHITE}(.config/nx/nxcore)${RESET}..."
    treefmt . --config-file "${NXCORE_DIR:-}/.treefmt.toml" "$@"
fi

if [[ -d "$CONFIG_DIR/.git" ]]; then
    echo
    echo -e "${GREEN}Formatting config repository ${WHITE}(.config/nx/nxconfig)${RESET}..."
    (cd "$CONFIG_DIR" && treefmt . "${CONFIG_DIR:-}/.treefmt.toml" "$@")
else
    echo
    echo -e "${YELLOW}Warning: Config directory does not exist or is no directory.${RESET}"
fi

