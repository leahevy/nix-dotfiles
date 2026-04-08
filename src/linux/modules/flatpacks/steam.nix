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

  group = "flatpacks";
  input = "linux";

  broken = true;

  settings = {
    package = "com.valvesoftware.Steam";
    appName = "steam";
    withWayland = false;
    withDataDir = false;
  };

  submodules = {
    linux = {
      software = {
        flatpack = true;
      };
    };
  };

  on = {
    ifEnabled.linux.desktop.niri.home = config: {
      programs.niri = {
        settings = {
          window-rules = [
            {
              matches = [
                {
                  app-id = "com.valvesoftware.Steam";
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
    };

    home =
      config:
      let
        dataDir = "${self.user.home}/.local/share/nx-flatpack";
        packageFile = "${dataDir}/${self.settings.package}.flatpack";
        withWayland = self.settings.withWayland;
        withDataDir = self.settings.withDataDir;
      in
      {
        home.sessionVariables = lib.optionalAttrs withWayland {
          STEAM_USE_WAYLAND = "1";
        };

        home.shellAliases = {
          "${self.settings.appName}" = "flatpak run ${self.settings.package}";
        };

        home.file."${packageFile}".text = ''
          PACKAGE_ID="${self.settings.package}"
          APP_NAME="${self.settings.appName}"

          mkdir -p "$HOME/.flatpack-homes/$APP_NAME"

          if ! ${pkgs.procps}/bin/pgrep -f "flatpak.*$PACKAGE_ID" > /dev/null; then
            ${
              self.notifyUser {
                inherit pkgs;
                title = "Flatpack";
                body = "Configuring $PACKAGE_ID";
                icon = "com.valvesoftware.Steam";
                urgency = "normal";
                validation = { inherit config; };
              }
            } || true
            ${pkgs.flatpak}/bin/flatpak override --user "$PACKAGE_ID" --reset
            ${pkgs.flatpak}/bin/flatpak override --user "$PACKAGE_ID" \
              --env=XDG_CONFIG_HOME="$HOME/.flatpack-homes/$APP_NAME/.config" \
              --env=XDG_DATA_HOME="$HOME/.flatpack-homes/$APP_NAME/.local/share" \
              --env=XDG_CACHE_HOME="$HOME/.flatpack-homes/$APP_NAME/.cache" \
              --filesystem=home/.flatpack-homes/$APP_NAME:rw \
              --filesystem=/tmp \
              ${lib.optionalString withDataDir "--filesystem=/data:rw"} \
              --share=network \
              --share=ipc \
              --socket=x11 \
              --socket=wayland \
              --socket=pulseaudio \
              --socket=session-bus \
              --device=dri \
              --device=all
            ${
              self.notifyUser {
                inherit pkgs;
                title = "Flatpack";
                body = "Successfully configured $PACKAGE_ID";
                icon = "com.valvesoftware.Steam";
                urgency = "normal";
                validation = { inherit config; };
              }
            } || true
          else
            ${
              self.notifyUser {
                inherit pkgs;
                title = "Flatpack";
                body = "$PACKAGE_ID is running, configuration will apply on next restart";
                icon = "com.valvesoftware.Steam";
                urgency = "normal";
                validation = { inherit config; };
              }
            } || true
          fi
        '';

        systemd.user.services."flatpack-configure-${self.settings.appName}" = {
          Unit = {
            Description = "Configure ${self.settings.package} Flatpak application";
            After = [ "flatpack-manager.service" ];
          };
          Service = {
            Type = "oneshot";
            ExecCondition = "${pkgs.bash}/bin/bash -c '${pkgs.flatpak}/bin/flatpak list --user | grep -q ${self.settings.package}'";
            ExecStart = "${pkgs.bash}/bin/bash ${packageFile}";
            Environment = [
              "PATH=${
                lib.makeBinPath [
                  pkgs.bash
                  pkgs.coreutils
                  pkgs.flatpak
                  pkgs.gnugrep
                  pkgs.procps
                  pkgs.libnotify
                ]
              }"
            ];
          };
          Install = {
            WantedBy = [ "flatpack-manager.service" ];
          };
        };

        home.persistence."${self.persist}" = {
          directories = [
            ".var/app/${self.settings.package}"
            ".flatpack-homes/${self.settings.appName}"
          ];
        };
      };
  };
}
