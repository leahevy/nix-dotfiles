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
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      sops.secrets.github_token = {
        sopsFile = self.config.secretsPath "global-secrets.yaml";
        path = "${config.xdg.configHome}/nix/github-token";
      };

      nix.extraOptions = ''
        !include ${config.xdg.configHome}/nix/github-token
      '';
    };
}
