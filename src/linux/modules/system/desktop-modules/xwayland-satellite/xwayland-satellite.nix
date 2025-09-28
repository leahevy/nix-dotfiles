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

  configuration =
    context@{ config, options, ... }:
    {
      environment.systemPackages = with pkgs; [
        pkgs-unstable.xwayland-satellite
      ];
    };
}
