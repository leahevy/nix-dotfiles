args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
{
  name = "flatpak";

  group = "software";
  input = "linux";

  options = {
    updateCalendar = lib.mkOption {
      type = lib.types.str;
      default = "*-*-* 18:00:00";
      description = "Systemd calendar expression for the flatpak auto-update timer";
    };
  };

  module = {
    enabled = config: {
      nx.lib.icons = [ "system-software-install" ];

      nx.linux.monitoring.journal-watcher.ignorePatterns = [
        {
          string = "libostree HTTP error from remote flathub for <https://dl\\.flathub\\.org/repo/objects/[0-9a-f]+/[0-9a-f]+\\.filez>: Timeout was reached";
          tag = "flatpak";
          user = true;
          unitless = true;
        }
      ];
    };

    ifEnabled.linux.desktop.niri.enabled = config: {
      nx.linux.monitoring.journal-watcher.ignorePatterns = [
        {
          string = "Failed to get application states: GDBus\\.Error:org\\.freedesktop\\.DBus\\.Error\\.UnknownInterface: No such interface 'org\\.freedesktop\\.impl\\.portal\\.Background' at object path '/org/freedesktop/portal/desktop'";
          user = true;
          unitless = true;
        }
      ];
    };

    ifEnabled.linux.desktop-modules.wayland.home = config: {
      services.flatpak.overrides.global.Context.sockets = [
        "wayland"
        "fallback-x11"
      ];
    };

    home =
      { config, updateCalendar, ... }:
      let
        notify =
          body: urgency: icon:
          self.notifyUser {
            inherit pkgs;
            title = "Flatpak";
            inherit body urgency icon;
            validation = { inherit config; };
          };

        flatpakUpdateScript = pkgs.writeShellScript "flatpak-update" ''
          set -euo pipefail

          LOCK_FILE="''${XDG_RUNTIME_DIR:-/tmp}/flatpak-update.lock"
          exec 9>"$LOCK_FILE"
          if ! ${pkgs.util-linux}/bin/flock -n 9; then
            ${notify "An update is already running" "normal" "system-software-install"} || true
            exit 0
          fi

          ${notify "Updating applications" "normal" "system-software-install"} || true

          if ${pkgs.systemd}/bin/systemctl --user start --wait flatpak-managed-install-timer.service; then
            ${notify "Successfully updated applications" "normal" "system-software-install"} || true
          else
            ${notify "Failed to update applications" "critical" "dialog-error"} || true
            exit 1
          fi
        '';
      in
      {
        services.flatpak = {
          enable = true;
          uninstallUnmanaged = true;
          remotes = [
            {
              name = "flathub";
              location = "https://flathub.org/repo/flathub.flatpakrepo";
            }
          ];
          update = {
            onActivation = false;
            auto = {
              enable = true;
              onCalendar = updateCalendar;
            };
          };
          restartOnFailure.exponentialBackoff.enable = true;
        };

        systemd.user.services.flatpak-managed-install.Unit.After = lib.mkForce [
          "graphical-session.target"
        ];

        home.file."${defs.binDir}/flatpak-update" = {
          source = flatpakUpdateScript;
        };

        xdg.desktopEntries.flatpak-update = {
          name = "Flatpak Update";
          comment = "Update flatpak applications";
          exec = "${flatpakUpdateScript}";
          icon = "system-software-install";
          terminal = false;
          categories = [ "System" ];
        };

        home.persistence."${self.persist}" = {
          directories = [
            ".local/share/flatpak"
          ]
          ++ map (
            p: ".var/app/${lib.head (lib.splitString "//" (if builtins.isString p then p else p.appId))}"
          ) config.services.flatpak.packages;
        };

        xdg.systemDirs.data = [
          "/var/lib/flatpak/exports/share"
          "${self.user.home}/.local/share/flatpak/exports/share"
        ];
      };

    standalone = config: {
      home.packages = [
        pkgs.flatpak
      ];
    };

    system = config: {
      services.flatpak.enable = true;

      environment.persistence."${self.persist}" = {
        directories = [
          "/var/lib/flatpak"
        ];
      };
    };
  };
}
