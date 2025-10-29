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
  name = "swaynotificationcenter";

  group = "desktop-modules";
  input = "linux";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      home.packages = with pkgs; [
        swaynotificationcenter
      ];

      home.file.".local/bin/scripts/toggle-dnd" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash

          set -euo pipefail

          current_state=$(swaync-client -D)

          if [ "$current_state" = "true" ]; then
            swaync-client -d > /dev/null 2>&1
            notify-send "Do Not Disturb" "Notifications enabled" --icon=audio-volume-medium
          else
            notify-send "Do Not Disturb" "Notifications disabled" --icon=audio-volume-muted
            sleep 5
            current_state=$(swaync-client -D)
            if [ "$current_state" = "false" ]; then
              swaync-client -d > /dev/null 2>&1
            fi
          fi
        '';
      };

      home.file.".config/swaync/config.json" = {
        text = ''
          {
            "$schema": "/etc/xdg/swaync/configSchema.json",
            "positionX": "right",
            "positionY": "top",
            "control-center-positionX": "none",
            "control-center-positionY": "none",
            "control-center-margin-top": 8,
            "control-center-margin-bottom": 8,
            "control-center-margin-right": 8,
            "control-center-margin-left": 8,
            "control-center-width": 500,
            "control-center-height": 1000,
            "fit-to-screen": false,
            "layer-shell-cover-screen": true,
            "layer-shell": true,
            "layer": "overlay",
            "control-center-layer": "overlay",
            "cssPriority": "user",
            "notification-body-image-height": 100,
            "notification-body-image-width": 200,
            "notification-inline-replies": true,
            "timeout": 60,
            "timeout-low": 60,
            "timeout-critical": 300,
            "notification-window-width": 500,
            "keyboard-shortcuts": true,
            "image-visibility": "when-available",
            "transition-time": 200,
            "hide-on-clear": true,
            "hide-on-action": true,
            "script-fail-notify": true,
            "widgets": [
              "inhibitors",
              "mpris",
              "notifications"
            ],
            "widget-config": {
              "notifications": {
                "vexpand": false
              },
              "inhibitors": {
                "text": "Inhibitors",
                "button-text": "Clear All",
                "clear-all-button": true
              },
              "title": {
                "text": "Notifications",
                "clear-all-button": false,
                "button-text": "Clear All"
              },
              "mpris": {
                "image-size": 96,
                "image-radius": 12
              }
            }
          }
        '';
      };

      home.file.".config/swaync/style.css" = {
        text = ''
          .control-center {
           background: rgba(0, 0, 0, 0.95);
           border-radius: 0;
           border: 1px solid rgba(255, 255, 255, 0.15);
          }

          .widgets > .widget,
          .widget-mpris > carouselindicatordots,
          .widget-mpris > box > button {
           background: rgba(0, 0, 0, 0.95);
           border-radius: 0;
           padding: 7px;
           border: 1px solid rgba(255, 255, 255, 0.15);
           color: #ffffff;
          }

          .control-center-list-placeholder {
           padding: 14px;
           color: #ffffff;
          }

          .notification-group {
           background: transparent;
           border-radius: 0;
           border: none;
           padding: 8px;
           margin: 4px 0;
          }

          .notification {
           background: rgba(0, 0, 0, 0.95);
           border-radius: 0;
           border: 1px solid rgba(255, 255, 255, 0.15);
           padding: 12px;
           margin: 4px 0;
           color: #ffffff;
          }

          .widget.widget-mpris {
           background: transparent;
           border-radius: 0;
           padding: 0;
           border: none;
          }

          .widget.widget-mpris > carouselindicatordots {
           padding: 4px;
           padding-left: 4px;
           padding-right: 10px;
           margin: 0;
           margin-top: 7px;
          }

          .widget-mpris > box > button:hover {
           background: rgba(0, 0, 0, 1);
          }

          .widget-mpris-player {
           box-shadow: none;
           border: 1px solid rgba(255, 255, 255, 0.15);
           margin: 0 7px;
          }

          .widget-mpris-player:only-child {
           margin: 0;
          }

          .notification-window {
           background: rgba(0, 0, 0, 0.95);
           border-radius: 0;
           border: 1px solid rgba(255, 255, 255, 0.15);
           margin: 8px;
          }

          .summary {
           font-weight: bold;
           color: #ffffff;
           font-size: 18px;
          }

          .body {
           color: #ffffff;
           font-size: 16px;
          }

          .notification .summary,
          .notification .body {
           padding-left: 16px;
          }
        '';
      };

      systemd.user.services.nx-swaynotificationcenter = {
        Unit = {
          Description = "SwayNotificationCenter notification daemon";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };

        Service = {
          ExecStart = "${pkgs.swaynotificationcenter}/bin/swaync";
          ExecReload = "${pkgs.swaynotificationcenter}/bin/swaync-client --reload-config && ${pkgs.swaynotificationcenter}/bin/swaync-client --reload-css";
          Environment = [
            "GTK_IM_MODULE=wayland"
          ];
          Restart = "on-failure";
          RestartSec = "1";
          Type = "simple";
        };

        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
      };

      programs.niri.settings = lib.mkIf (self.isModuleEnabled "desktop.niri") {
        binds = with config.lib.niri.actions; {
          "Mod+N" = {
            action = spawn "swaync-client" "--close-latest";
            hotkey-overlay.title = "Notifications:Dismiss notification";
          };
          "Mod+M" = {
            action = spawn "swaync-client" "-t" "-sw";
            hotkey-overlay.title = "Notifications:Toggle control center";
          };
          "Mod+Shift+N" = {
            action = spawn "swaync-client" "-C";
            hotkey-overlay.title = "Notifications:Clear all notifications";
          };
          "Mod+Shift+M" = {
            action = spawn-sh "${config.home.homeDirectory}/.local/bin/scripts/toggle-dnd";
            hotkey-overlay.title = "Notifications:Toggle do not disturb";
          };
        };
      };
    };
}
