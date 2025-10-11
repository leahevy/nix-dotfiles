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
  name = "mako";

  configuration =
    context@{ config, options, ... }:
    {
      services.mako = {
        enable = true;

        settings = {
          font = lib.mkForce "monospace 12";
          background-color = lib.mkForce "#0a0a0fee";
          text-color = lib.mkForce "#ffffff";
          border-color = lib.mkForce "#ffffff26";
          progress-color = lib.mkForce "#ffffff";

          width = 400;
          height = 200;
          margin = "8";
          padding = "20";
          border-size = 1;
          border-radius = 14;

          default-timeout = 1800000;
          group-by = "app-name";
          sort = "-time";
          layer = "overlay";
          anchor = "top-left";

          markup = true;
          max-visible = 8;

          actions = true;

          "actionable=true" = {
            anchor = "top-right";
          };
        };
      };

      systemd.user.services.mako = {
        Service = {
          ExecStartPre = [
            "/bin/sh -c 'sleep 2'"
          ];
        };
      };

      programs.niri.settings = lib.mkIf (self.isModuleEnabled "desktop.niri") {
        binds = with config.lib.niri.actions; {
          "Mod+N" = {
            action = spawn "makoctl" "dismiss";
            hotkey-overlay.title = "Notifications:Dismiss notification";
          };
          "Mod+Shift+N" = {
            action = spawn "makoctl" "restore";
            hotkey-overlay.title = "Notifications:Restore notification";
          };
          "Mod+M" = {
            action = spawn "makoctl" "dismiss" "--all";
            hotkey-overlay.title = "Notifications:Dismiss all notifications";
          };
        };
      };
    };
}
