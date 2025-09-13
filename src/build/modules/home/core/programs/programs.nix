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
  name = "programs";

  configuration =
    context@{ config, options, ... }:
    {
      home = {
        packages = (
          with pkgs;
          [
            git
            htop
            vim
            nixfmt-rfc-style
            nixfmt-tree
            nix-prefetch-github
            git-crypt
            pre-commit
            sops
            age
            ssh-to-age
            ssh-to-pgp
          ]
        );
      };
    };
}
