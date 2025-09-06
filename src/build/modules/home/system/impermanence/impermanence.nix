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
  configuration =
    context@{ config, options, ... }:
    {
      config = lib.mkIf (!self.user.isStandalone && self.isLinux && (self.host.impermanence or false)) {
        home.persistence."${self.persist}" = {
          directories = [
            ".config/nx"
            ".config/nix"
            ".config/sops"
            ".cache/nix"
          ];

          files = [
            ".bash_history"
            ".zsh_history"
          ];

          allowOther = true;
        };
      };
    };
}
