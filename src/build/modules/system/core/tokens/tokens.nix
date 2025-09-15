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
  name = "tokens";

  configuration =
    context@{ config, options, ... }:
    {
      sops.secrets.github_token = {
        sopsFile = self.config.secretsPath "global-secrets.yaml";
        path = "/etc/nix/github-token";
        mode = "0400";
        owner = "root";
        group = "root";
      };

      nix.extraOptions = ''
        !include /etc/nix/github-token
      '';
    };
}
