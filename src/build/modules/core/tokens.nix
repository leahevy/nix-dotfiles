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
  group = "core";
  input = "build";

  module = {
    home = config: {
      sops.secrets.github_token = {
        sopsFile = self.config.secretsPath "global-secrets.yaml";
        path = "${config.xdg.configHome}/nix/github-token";
      };

      nix.extraOptions = ''
        !include ${config.xdg.configHome}/nix/github-token
      '';
    };

    system = config: {
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
  };
}
