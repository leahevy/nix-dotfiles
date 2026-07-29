te_secrets global yaml global-secrets.yaml user-secrets.yaml host-secrets.yaml

te_secrets integrated:testuser-desktop binary \
	bitwarden-api-token \
	syncthing-test-encryption.password \
	syncthing.api-key \
	syncthing.cert \
	syncthing.key \
	syncthing.password

te_secrets nixos:testing binary \
	tailscale-auth-key \
	borg.known-hosts \
	borg.passphrase \
	borg.ssh-key
