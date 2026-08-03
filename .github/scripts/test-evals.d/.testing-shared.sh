te_variables \
	'cudaArchitectures = [ "sm_00" ];' \
	'isoManagementSSHKey = { public = "ssh-ed25519 AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA test@example.com"; };'

te_secrets global yaml global-secrets.yaml user-secrets.yaml host-secrets.yaml
te_secrets global binary letsencrypt-dns pushover-e2e-key pushover-user

te_secrets integrated:testuser-desktop binary \
	bitwarden-api-token \
	syncthing-test-encryption.password \
	syncthing.api-key \
	syncthing.cert \
	syncthing.key \
	syncthing.password \
	cryptomator-secret-pass \
	wallet.pass

te_secrets nixos:testing binary \
	tailscale-auth-key \
	borg.known-hosts \
	borg.passphrase \
	borg.ssh-key \
	bitwarden-api-token \
	pushover-token \
	yubikey-u2f-keys \
	smtp-password

te_secrets nixos:testing-server binary \
	borg.known-hosts \
	borg.passphrase \
	borg.ssh-key
