#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
deployment_script_setup "version"

if output=$(nix eval .#nixpkgs.lib.version --raw 2>/dev/null); then
    echo -e "${GREEN}NixOS Version:${RESET} $output"
else
    exit_code=$?
    nix eval .#nixpkgs.lib.version --raw
    exit $exit_code
fi
