args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
{
  name = "direnv";

  group = "dev";
  input = "common";

  module = {
    enabled = config: {
      nx.common.git.git.globalIgnores = [
        ".envrc*"
        ".direnv"
      ];
    };

    home = config: {
      programs = {
        direnv = {
          enable = true;
        };
      };
    };

    darwin.overlays = [
      (final: prev: {
        direnv = prev.direnv.overrideAttrs (oldAttrs: {
          env = (oldAttrs.env or { }) // {
            CGO_ENABLED = "1";
          };
        });
      })
    ];
  };
}
