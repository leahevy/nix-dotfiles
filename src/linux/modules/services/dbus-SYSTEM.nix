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

  group = "services";
  input = "linux";
  namespace = "system";

  configuration =
    context@{ config, options, ... }:
    {
      services.dbus = {
        enable = true;
        implementation = "broker";
      };
    };
}
