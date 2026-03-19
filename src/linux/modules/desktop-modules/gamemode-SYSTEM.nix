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
  name = "gamemode";

  group = "desktop-modules";
  input = "linux";
  namespace = "system";

  configuration =
    context@{ config, options, ... }:
    {
      programs.gamemode = {
        enable = true;
        settings = {
          general = {
            renice = 10;
          };

          custom = {
            start = "${pkgs.libnotify}/bin/notify-send 'GameMode started' --icon=com.valvesoftware.Steam";
            end = "${pkgs.libnotify}/bin/notify-send 'GameMode ended' --icon=com.valvesoftware.Steam";
          };
        };
      };
    };
}
