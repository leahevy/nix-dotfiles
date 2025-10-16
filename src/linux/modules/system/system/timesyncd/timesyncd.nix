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

  group = "system";
  input = "linux";
  namespace = "system";

  configuration =
    context@{ config, options, ... }:
    {
      services.timesyncd = {
        enable = lib.mkForce true;
      };
    };
}
