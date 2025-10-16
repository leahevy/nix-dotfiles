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
  name = "sops";
  group = "core";
  input = "build";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      sops = {
        defaultSopsFile =
          if self.user.isStandalone then
            self.config.secretsPath "standalone-secrets.yaml"
          else
            self.config.secretsPath "user-secrets.yaml";

        age.keyFile =
          if self.user.isStandalone then
            "${config.xdg.configHome}/sops/age/keys.txt"
          else if self.host.impermanence or false then
            "${self.variables.persist.home}/${self.user.username}/.config/sops/age/keys.txt"
          else
            "${config.xdg.configHome}/sops/age/keys.txt";
      };

      home.sessionVariables = {
        SOPS_AGE_KEY_FILE =
          if self.user.isStandalone then
            "${config.xdg.configHome}/sops/age/keys.txt"
          else if self.host.impermanence or false then
            "${self.variables.persist.home}/${self.user.username}/.config/sops/age/keys.txt"
          else
            "${config.xdg.configHome}/sops/age/keys.txt";
      };

      systemd.user.services.sops-nix = lib.mkIf self.isLinux {
        Service = {
          Environment = lib.mkForce [
            "GNUPGHOME=/nonexistent"
          ];
        };
      };
    };
}
