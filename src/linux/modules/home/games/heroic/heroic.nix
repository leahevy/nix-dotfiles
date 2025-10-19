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

  group = "games";
  input = "linux";
  namespace = "home";

  submodules = {
    linux = {
      games = {
        utils = true;
      };
      graphics = {
        opengl = true;
      };
    };
  };

  defaults = {
    withWayland = false;
    games = {
      stardewValley = false;
      torchlightII = false;
    };
    additionalGameStateDirs = [ ];
    withUmu = true;
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
          ".local/share/GOG.com"
        ]
        ++ lib.optionals self.settings.games.stardewValley [
          ".config/StardewValley"
        ]
        ++ lib.optionals self.settings.games.torchlightII [
          ".local/share/Runic Games/Torchlight 2"
        ]
        ++ lib.optionals self.settings.withUmu [
          ".local/share/umu"
          ".cache/umu"
          ".cache/umu-protonfixes"
        ]
        ++ self.settings.additionalGameStateDirs;
      };
    };
}
