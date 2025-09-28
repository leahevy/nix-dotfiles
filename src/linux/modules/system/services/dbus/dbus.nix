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
  name = "dbus";

  configuration =
    context@{ config, options, ... }:
    {
      services.dbus = {
        enable = true;
        implementation = "broker";
      };
    };
}
