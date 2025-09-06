#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/pre-check.sh"
simple_deployment_script_setup "exec"

"$@"
