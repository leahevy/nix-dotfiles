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

  group = "games";
  input = "linux";
  namespace = "system";

  unfree = [
    "steam"
    "steam-unwrapped"
  ];

  settings = {
    dataPath = null;
  };

  configuration =
    context@{ config, options, ... }:
    let
      steamHomeConfig = self.user.getModuleConfig "games.steam";
      withWayland = steamHomeConfig.withWayland or false;
      dataPath = self.settings.dataPath;

      wrapSteamBinary =
        pkg: binaryName:
        if (dataPath != null) then
          pkg.overrideAttrs (oldAttrs: {
            nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];
            postInstall = (oldAttrs.postInstall or "") + ''
              wrapProgram $out/bin/${binaryName} \
                --set HOME "${dataPath}" \
                --set XDG_DATA_HOME "${dataPath}/.local/share" \
                --set XDG_CONFIG_HOME "${dataPath}/.config" \
                --set XDG_CACHE_HOME "${dataPath}/.cache" \
                --set XDG_STATE_HOME "${dataPath}/.local/state"
            '';
          })
        else
          pkg;

      customPkgs =
        if (dataPath != null) then
          self.pkgs {
            overlays = [
              (final: prev: {
                protonup-ng = wrapSteamBinary prev.protonup-ng "protonup";
                protontricks = wrapSteamBinary prev.protontricks "protontricks";
              })
            ];
          }
        else
          { };
    in
    {
      programs.steam = {
        enable = true;
        package =
          if (dataPath != null) then
            pkgs.steam.override {
              extraEnv = {
                HOME = dataPath;
                XDG_DATA_HOME = "${dataPath}/.local/share";
                XDG_CONFIG_HOME = "${dataPath}/.config";
                XDG_CACHE_HOME = "${dataPath}/.cache";
                XDG_STATE_HOME = "${dataPath}/.local/state";
              };
            }
          else
            pkgs.steam;

        remotePlay.openFirewall = true;
        dedicatedServer.openFirewall = true;
        localNetworkGameTransfers.openFirewall = true;
        gamescopeSession.enable = true;

        extraCompatPackages = with pkgs; [
          proton-ge-bin
        ];
      };

      security.wrappers.gamescope = {
        source = "${pkgs.gamescope}/bin/gamescope";
        capabilities = "cap_sys_nice+ep";
        owner = "root";
        group = "root";
      };

      environment.systemPackages = [
        customPkgs.protonup-ng or pkgs.protonup-ng
        customPkgs.protontricks or pkgs.protontricks
      ]
      ++ (with pkgs; [
        mangohud
        winetricks
        (if withWayland then wineWowPackages.waylandFull else wineWowPackages.stable)
      ]);

      environment.sessionVariables = {
        STEAM_EXTRA_COMPAT_TOOLS_PATHS =
          if (dataPath != null) then
            "${dataPath}/.steam/root/compatibilitytools.d"
          else
            "$HOME/.steam/root/compatibilitytools.d";
      }
      // lib.optionalAttrs withWayland {
        STEAM_USE_WAYLAND = "1";
      };
    };
}
