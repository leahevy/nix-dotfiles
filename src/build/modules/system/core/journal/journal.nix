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
  name = "journal";

  group = "core";
  input = "build";
  namespace = "system";

  configuration =
    context@{ config, options, ... }:
    {
      services.journald.extraConfig = ''
        ForwardToWall=no
      '';
    };
}
