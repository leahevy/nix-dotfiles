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

  on = {
    darwin.overlays = [
      (final: prev: {
        pre-commit = prev.pre-commit.overridePythonAttrs (oldAttrs: {
          disabledTests = (oldAttrs.disabledTests or [ ]) ++ [
            "test_output_isatty"
          ];
        });
      })
    ];

    home = config: {
      home = {
        packages = with pkgs; [
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
          pre-commit
        ];
      };
    };
  };
}
