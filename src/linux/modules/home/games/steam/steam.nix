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

  defaults = {
    withWayland = false;
  };

  assertions = [
    {
      assertion =
        (self.user.isStandalone or false) || (self.host.isModuleEnabled or (x: false)) "games.steam";
      message = "The steam home module requires the steam system module to be enabled when not running standalone";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    let
      isNiriEnabled = self.isLinux && self.linux.isModuleEnabled "desktop.niri";
      isStandalone = self.user.isStandalone or false;
      withWayland = self.settings.withWayland;
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

        home.persistence."${self.persist}" = {
          directories = [
            ".local/share/Steam"
            ".steam"
          ];
        };
      }
      (lib.mkIf isStandalone {
        home.packages = with pkgs-unstable; [
          steam
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

        home.sessionVariables = {
          STEAM_EXTRA_COMPAT_TOOLS_PATHS = "$HOME/.steam/root/compatibilitytools.d";
        }
        // lib.optionalAttrs withWayland {
          STEAM_USE_WAYLAND = "1";
        };
      })
    ];
}
