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
  name = "sudo";

  configuration =
    context@{ config, options, ... }:
    {
      security.sudo.extraConfig = ''
        Defaults lecture = never
      '';
    };
}
