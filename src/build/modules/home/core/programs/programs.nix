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
  group = "core";
  input = "build";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    let
      customPkgs =
        if self.isDarwin then
          self.pkgs {
            overlays = [
              (final: prev: {
                pre-commit = prev.pre-commit.overridePythonAttrs (oldAttrs: {
                  disabledTests = (oldAttrs.disabledTests or [ ]) ++ [
                    "test_output_isatty"
                  ];
                });
              })
            ];
          }
        else
          pkgs;
    in
    {
      home = {
        packages =
          (with pkgs; [
            git
            htop
            vim
            nixfmt-rfc-style
            nixfmt-tree
            nix-prefetch-github
            git-crypt
            sops
            age
            ssh-to-age
            ssh-to-pgp
            nvd
          ])
          ++ [
            customPkgs.pre-commit
          ];
      };
    };
}
