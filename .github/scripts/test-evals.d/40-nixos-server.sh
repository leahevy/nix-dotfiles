#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../test-eval-lib.sh"

te_setup
te_secrets global yaml global-secrets.yaml user-secrets.yaml host-secrets.yaml
te_secrets global binary letsencrypt-dns
te_secrets integrated:testuser binary bitwarden-api-token
te_secrets nixos:testing-server binary \
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
	searxng-brave-api-key
te_eval nixos "testing-server--x86_64-linux"
