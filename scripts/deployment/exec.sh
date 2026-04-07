#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/../utils/common.sh"
simple_deployment_script_setup "exec"

"$@"
