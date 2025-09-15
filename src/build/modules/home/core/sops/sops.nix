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
    };
}
