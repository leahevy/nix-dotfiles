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

  unfree = [
    "steam"
    "steam-unwrapped"
  ];

  submodules = {
    linux = {
      games = {
        common = true;
      };
    };
  };

  settings = {
    withWayland = false;
    dataPath = null;
  };

  on = {
    home =
      config:
      let
        isNiriEnabled = self.isLinux && self.linux.isModuleEnabled "desktop.niri";
        isStandalone = self.user.isStandalone or false;
        withWayland = self.settings.withWayland;
        usesDataPath = self.settings.dataPath != null;
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
                "${self.settings.dataPath}/.steam/root/compatibilitytools.d"
              else
                "$HOME/.steam/root/compatibilitytools.d";
          }
          // lib.optionalAttrs withWayland {
            STEAM_USE_WAYLAND = "1";
          };
        })
      ];

    system =
      config:
      let
        withWayland = self.settings.withWayland;
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

        wrappedProtonupNg = wrapSteamBinary pkgs.protonup-ng "protonup";
        wrappedProtontricks = wrapSteamBinary pkgs.protontricks "protontricks";
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
          wrappedProtonupNg
          wrappedProtontricks
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
  };
}
