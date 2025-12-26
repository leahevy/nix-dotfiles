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
  namespace = "home";

  unfree = [
    "steam"
    "steam-unwrapped"
  ];

  settings = {
    withWayland = false;
  };

  configuration =
    context@{ config, options, ... }:
    let
      isNiriEnabled = self.isLinux && self.linux.isModuleEnabled "desktop.niri";
      isStandalone = self.user.isStandalone or false;
      withWayland = self.settings.withWayland;
      nixOSSettings = if isStandalone then { } else self.host.getModuleConfig "games.steam";
      usesDataPath = (nixOSSettings.dataPath or null) != null;
    in
    lib.mkMerge [
      {
        programs.niri = lib.mkIf isNiriEnabled {
          settings = {
            window-rules = [
              {
                matches = [
                  {
                    app-id = "steam";
                    title = "^notificationtoasts_\\d+_desktop$";
                  }
                ];
                default-floating-position = {
                  x = 10;
                  y = 10;
                  relative-to = "bottom-right";
                };
              }
            ];
          };
        };

        home.persistence."${self.persist}" = lib.mkIf (!usesDataPath) {
          directories = [
            ".local/share/Steam"
            ".steam"
          ];
        };
      }
      (lib.mkIf isStandalone {
        home.packages = with pkgs; [
          steam
          mangohud
          protonup-ng
          protontricks
          winetricks
          (if withWayland then wineWowPackages.waylandFull else wineWowPackages.stable)
        ];

        home.sessionVariables = {
          STEAM_EXTRA_COMPAT_TOOLS_PATHS =
            if (!isStandalone && usesDataPath) then
              "${nixOSSettings.dataPath}/.steam/root/compatibilitytools.d"
            else
              "$HOME/.steam/root/compatibilitytools.d";
        }
        // lib.optionalAttrs withWayland {
          STEAM_USE_WAYLAND = "1";
        };
      })
    ];
}
