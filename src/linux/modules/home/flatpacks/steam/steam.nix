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
  namespace = "home";

  broken = true;

  defaults = {
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

  configuration =
    context@{ config, options, ... }:
    let
      dataDir = "${self.user.home}/.local/share/nx-flatpack";
      packageFile = "${dataDir}/${self.settings.package}.flatpack";
      isNiriEnabled = self.isLinux && self.linux.isModuleEnabled "desktop.niri";
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

      programs.niri = lib.mkIf isNiriEnabled {
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

      home.file."${packageFile}".text = ''
        PACKAGE_ID="${self.settings.package}"
        APP_NAME="${self.settings.appName}"

        mkdir -p "$HOME/.flatpack-homes/$APP_NAME"

        if ! ${pkgs.procps}/bin/pgrep -f "flatpak.*$PACKAGE_ID" > /dev/null; then
          ${pkgs.libnotify}/bin/notify-send "Flatpack" "Configuring $PACKAGE_ID" --icon=com.valvesoftware.Steam || true
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
          ${pkgs.libnotify}/bin/notify-send "Flatpack" "Successfully configured $PACKAGE_ID" --icon=com.valvesoftware.Steam || true
        else
          ${pkgs.libnotify}/bin/notify-send "Flatpack" "$PACKAGE_ID is running, configuration will apply on next restart" --icon=com.valvesoftware.Steam || true
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
}
