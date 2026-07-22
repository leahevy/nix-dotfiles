#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../test-eval-lib.sh"

te_setup
te_secrets global yaml global-secrets.yaml user-secrets.yaml host-secrets.yaml
te_secrets integrated:testuser binary bitwarden-api-token
te_eval nixos "testing--x86_64-linux"
