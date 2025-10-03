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
  name = "steam";

  assertions = [
    {
      assertion = self.user.isModuleEnabled "games.steam";
      message = "The steam system module requires the steam home module to be enabled";
    }
  ];

  unfree = [
    "steam"
  ];

  configuration =
    context@{ config, options, ... }:
    let
      steamHomeConfig = self.user.getModuleConfig "games.steam";
      withWayland = steamHomeConfig.withWayland or false;
    in
    {
      programs.steam = {
        enable = true;

        remotePlay.openFirewall = true;
        dedicatedServer.openFirewall = true;
        localNetworkGameTransfers.openFirewall = true;
        gamescopeSession.enable = true;

        extraCompatPackages = with pkgs; [
          proton-ge-bin
        ];
      };

      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };

      security.wrappers.gamescope = {
        source = "${pkgs.gamescope}/bin/gamescope";
        capabilities = "cap_sys_nice+ep";
        owner = "root";
        group = "root";
      };

      environment.systemPackages = with pkgs; [
        steam-run
        mangohud
        protonup
        protontricks
        lutris
        bottles
        heroic
        winetricks
        (if withWayland then wineWowPackages.waylandFull else wineWowPackages.stable)
      ];

      environment.sessionVariables = {
        STEAM_EXTRA_COMPAT_TOOLS_PATHS = "$HOME/.steam/root/compatibilitytools.d";
      }
      // lib.optionalAttrs withWayland {
        STEAM_USE_WAYLAND = "1";
      };
    };
}
