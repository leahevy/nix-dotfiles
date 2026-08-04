#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../test-eval-lib.sh"

te_setup
te_variables "configRepoURL = \"$TEST_EVAL_TEMPLATE_REPO_URL\";"
te_secrets global yaml global-secrets.yaml user-secrets.yaml host-secrets.yaml auto-upgrade-signing-keys.yaml
te_secrets global binary letsencrypt-dns pushover-user
te_secrets integrated:testuser-server binary bitwarden-api-token
te_secrets nixos:testing-server binary \
	luks-cryptdata-keyfile \
	pushover-token \
	oauth-proxy-client-id \
	oauth-proxy-client-secret \
	paperless-admin-pass \
	paperless-oidc-id \
	paperless-oidc-secret \
	paperless-searxng \
	pocket-id-api-key \
	samba-pass-testldap \
	syncthing-gui-pass \
	syncthing-server.key \
	syncthing-server.cert \
	healthchecks-uuid \
	healthchecks-readonly-api-key \
	openldap-root-pass \
	openldap-reader-pass \
	searxng-brave-api-key \
	ollama-api-key \
	todoist-api-token
te_eval nixos "testing-server--x86_64-linux"
