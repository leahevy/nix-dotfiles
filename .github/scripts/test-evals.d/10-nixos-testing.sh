#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../test-eval-lib.sh"

te_setup
source "$(dirname "${BASH_SOURCE[0]}")/.testing-shared.sh"
te_eval nixos "testing--x86_64-linux"
