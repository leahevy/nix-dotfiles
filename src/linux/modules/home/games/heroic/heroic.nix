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
  name = "heroic";

  submodules = {
    linux = {
      graphics = {
        opengl = true;
      };
    };
  };

  defaults = {
    withWayland = false;
  };

  configuration =
    context@{ config, options, ... }:
    let
      withWayland = self.settings.withWayland;
    in
    {
      home.packages = with pkgs-unstable; [
        heroic
        steam-run
        mangohud
        protonup
        protontricks
        lutris
        bottles
        winetricks
        (if withWayland then wineWowPackages.waylandFull else wineWowPackages.stable)
      ];

      home.persistence."${self.persist}" = {
        directories = [
          ".config/heroic"
          ".local/share/comet"
          ".local/state/Heroic/logs"
          ".config/unity3d"
        ];
      };
    };
}
