args@{
  lib,
  pkgs,
  pkgs-unstable,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
{
  name = "bitwarden-secret";

  group = "security";
  input = "linux";
  namespace = "system";

  unfree = [ "bws" ];

  settings = {
    serverURL = "https://vault.bitwarden.eu";
  };

  configuration =
    context@{ config, options, ... }:
    let
      bitwarden-get-secret = pkgs.writeShellScriptBin "bitwarden-get-secret" ''
        set -euo pipefail

        SECRET_UUID="''${1:-}"
        if [[ -z "$SECRET_UUID" ]]; then
          echo "Usage: bitwarden-get-secret <SECRET_UUID>" >&2
          exit 1
        fi

        if [[ ! "$SECRET_UUID" =~ ^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$ ]]; then
          echo "Error: Invalid UUID format" >&2
          exit 2
        fi

        TOKEN_FILE="/run/secrets/bitwarden-api-token"
        if [[ ! -r "$TOKEN_FILE" ]]; then
          echo "Error: Cannot read token file" >&2
          exit 3
        fi

        export BWS_ACCESS_TOKEN="$(cat "$TOKEN_FILE")"
        SECRET="$(${pkgs.bws}/bin/bws secret get --server-url "${self.settings.serverURL}" "$SECRET_UUID" 2>/dev/null | ${pkgs.jq}/bin/jq -r ".value" 2>/dev/null)"

        if [[ -n "$SECRET" && "$SECRET" != "null" ]]; then
          cat <<< "$SECRET"
        else
          echo "Error: Failed to retrieve secret" >&2
          exit 4
        fi
      '';
    in
    {
      sops.secrets."bitwarden-api-token" = {
        format = "binary";
        sopsFile = self.config.secretsPath "bitwarden-api-token";
        mode = "0400";
        owner = "root";
        group = "root";
      };

      environment.systemPackages = [
        pkgs.bws
        pkgs.jq
        bitwarden-get-secret
      ];
    };
}
