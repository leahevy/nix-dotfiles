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
  name = "direnv";

  group = "dev";
  input = "common";

  module = {
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
