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
  name = "inetutils";
  group = "darwin";
  input = "overlays";

  module = {
    darwin.overlays = [
      (final: prev: {
        inetutils = prev.inetutils.overrideAttrs (oldAttrs: {
          env = (oldAttrs.env or { }) // {
            NIX_CFLAGS_COMPILE = (oldAttrs.env.NIX_CFLAGS_COMPILE or "") + " -Wno-error=format-security";
          };
          XFAIL_TESTS = "ping-localhost.sh";
        });
      })
    ];
  };
}
