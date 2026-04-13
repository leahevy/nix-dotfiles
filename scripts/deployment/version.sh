#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/common.sh"
deployment_script_setup "version"

if output=$(nix eval .#nixpkgs.lib.version --raw --override-input core "path:$NXCORE_DIR" 2>/dev/null); then
    echo -e "${GREEN}NixOS Version:${RESET} $output"
else
    exit_code=$?
    nix eval .#nixpkgs.lib.version --raw --override-input core "path:$NXCORE_DIR"
    exit $exit_code
fi
