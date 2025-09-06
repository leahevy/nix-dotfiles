#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
deployment_script_setup "news"

ensure_standalone_only "news"

PROFILE="$(retrieve_active_profile)"

home-manager news --flake .#$PROFILE --override-input config "path:$CONFIG_DIR"
