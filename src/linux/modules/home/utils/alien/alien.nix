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
      home = {
        shellAliases =
          if self.isLinux then
            {
              nix-alien = "nix run \"github:thiagokokada/nix-alien#nix-alien\" -- ";
              nix-alien-ld = "nix run \"github:thiagokokada/nix-alien#nix-alien-ld\" -- ";
              nix-alien-find-libs = "nix run \"github:thiagokokada/nix-alien#nix-alien-find-libs\" -- ";
            }
          else
            throw "Alien only works on Linux!";
      };
    };
}
