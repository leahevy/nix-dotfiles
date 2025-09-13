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
  name = "timesyncd";

  configuration =
    context@{ config, options, ... }:
    {
      services.timesyncd = {
        enable = lib.mkForce true;
      };
    };
}
