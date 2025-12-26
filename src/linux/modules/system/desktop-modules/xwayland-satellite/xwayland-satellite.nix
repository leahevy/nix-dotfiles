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
  name = "xwayland-satellite";

  group = "desktop-modules";
  input = "linux";
  namespace = "system";

  configuration =
    context@{ config, options, ... }:
    {
      environment.systemPackages = with pkgs; [
        pkgs.xwayland-satellite
      ];
    };
}
