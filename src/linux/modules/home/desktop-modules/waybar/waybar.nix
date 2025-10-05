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
  name = "waybar";

  defaults = {
    niri = false;
    output = null;
    addDataDisk = false;
    terminal = "ghostty";
  };

  submodules = {
    linux = {
      desktop-modules = {
        fuzzel = true;
      };
    };
  };

  configuration =
    context@{ config, options, ... }:
    let
      programsConfig = self.getModuleConfig "desktop-modules.programs";
    in
    {
      home.packages =
        with pkgs;
        [
          nixos-icons
          lm_sensors
          pavucontrol
        ]
        ++ (lib.optionals (self.host.isModuleEnabled "bluetooth.bluetooth") [
          pkgs.blueman
        ]);
      services.blueman-applet.enable = lib.mkForce false;

      programs.waybar = {
        enable = true;
        systemd = {
          enable = true;
          target = "graphical-session.target";
        };
        settings = {
          mainBar = {
            layer = "bottom";
            position = "top";
            height = 71;
            spacing = 3;
          }
          // lib.optionalAttrs (self.settings.output != null) {
            output = self.settings.output;
          }
          // {

            modules-left = [
              "custom/gap"
            ]
            ++ (lib.optionals self.settings.niri [ "group/workspacesgroup" ])
            ++ [
              "custom/nix"
              "custom/gap"
              "group/systemgroup"
              "custom/arrow"
            ];
            modules-center = [ "group/windowgroup" ];
            modules-right = [
              "group/traygroup"
              "group/statusgroup"
              "group/timegroup"
            ];

          }
          // lib.optionalAttrs self.settings.niri {
            "group/workspacesgroup" = {
              orientation = "horizontal";
              modules = [ "niri/workspaces" ];
            };

            "niri/workspaces" = {
              format = "{name}";
              all-outputs = true;
              current-only = false;
            };

            "group/windowgroup" = {
              orientation = "horizontal";
              modules = [
                "niri/window"
                "custom/separator"
                "niri/window#app-id"
              ];
              drawer = {
                transition-duration = 500;
                children-class = "app-id";
                transition-left-to-right = true;
                click-to-reveal = true;
              };
            };

            "niri/window" = {
              format = "{title}";
              icon = true;
              icon-size = 24;
              separate-outputs = false;
            };

            "niri/window#app-id" = {
              format = "{app_id}";
              icon = false;
              separate-outputs = false;

            };
          }
          // {
            "custom/nix" = {
              format = " ";
              interval = "once";
              tooltip = false;
              class = "nix";
              on-click = "fuzzel";
            };

            "custom/separator" = {
              format = "<b>|</b>";
              interval = "once";
              tooltip = false;
              class = "separator";
            };

            "custom/arrow" = {
              format = "⇒ ";
              interval = "once";
              tooltip = false;
              class = "separator";
            };

            "custom/gap" = {
              format = " ";
              interval = "once";
              tooltip = false;
              class = "gap";
            };

            "group/systemgroup" = {
              orientation = "horizontal";
              modules = [
                "load"
                "cpu"
                "memory"
                "memory#swap"
                "disk"
              ]
              ++ (if self.settings.addDataDisk then [ "disk#2" ] else [ ])
              ++ [
                "temperature"
                "custom/separator"
                "systemd-failed-units"
              ];
            };

            "group/traygroup" = {
              orientation = "horizontal";
              modules = [ "tray" ];
            };

            cpu = {
              format = "{usage}% 󰍛";
              tooltip = false;
              interval = 2;
              on-click = "${self.settings.terminal} -e htop";
            };

            memory = {
              format = "{percentage}% 󰾆";
              tooltip-format = "RAM: {used:0.1f}G/{total:0.1f}G";
              interval = 2;
              on-click = "${self.settings.terminal} -e htop";
            };

            "memory#swap" = {
              format = "{swapPercentage}% 󰓡";
              tooltip-format = "Swap: {swapUsed:0.1f}G/{swapTotal:0.1f}G";
              interval = 2;
              on-click = "${self.settings.terminal} -e htop";
            };

            disk = {
              format = "/: {percentage_used}% 󰋊";
              path = "/";
              tooltip-format = "Used on /: {used} / {total}";
              interval = 30;
              on-click = "${self.settings.terminal} -e sh -c 'echo && df -h | less'";
            };

            "disk#2" = {
              format = "/data: {percentage_used}% 󰆼";
              path = "/data";
              tooltip-format = "Used on /data: {used} / {total}";
              interval = 30;
              on-click = "${self.settings.terminal} -e sh -c 'echo && df -h | less'";
            };

            temperature = {
              format = "{temperatureC}°C ";
              thermal-zone = 0;
              on-click = "${self.settings.terminal} -e sh -c 'echo && sensors | less'";
            };

            load = {
              format = "{load1} 󰾅";
              on-click = "${self.settings.terminal} -e htop";
            };

            systemd-failed-units = {
              hide-on-ok = false;
              format = "✗ {nr_failed}";
              format-ok = "✓ OK";
              system = true;
              user = true;
              on-click = "${self.settings.terminal} -e sh -c 'echo && echo -e \"\\033[1;32m=== SYSTEM FAILED UNITS ===\\033[0m\" && echo && systemctl --failed --no-pager && echo && echo && echo && echo && echo -e \"\\033[1;32m=== USER FAILED UNITS ===\\033[0m\" && echo && systemctl --user --failed --no-pager && echo && echo && echo && echo \"Press any key to exit...\" && read -n 1'";
            };

            "group/timegroup" = {
              orientation = "horizontal";
              modules = [ "clock" ];
            };

            clock = {
              format = "󰃭 {:%I:%M %p}";
              format-alt = "󰃭 {:%I:%M %p, %d/%m/%EY}";
              tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
              calendar = {
                mode = "year";
                mode-mon-col = 3;
                weeks-pos = "left";
                on-scroll = 1;
                format = {
                  months = "<span color='#ffead3'><b>{}</b></span>";
                  days = "<span color='#ecc6d9'><b>{}</b></span>";
                  weeks = "<span color='#99ffdd'><b>W{}</b></span>";
                  weekdays = "<span color='#ffcc66'><b>{}</b></span>";
                  today = "<span color='#ff6699'><b><u>{}</u></b></span>";
                };
              };
            };

            "group/statusgroup" = {
              orientation = "horizontal";
              modules = [
                "privacy"
                "pulseaudio"
                "custom/gap"
                "pulseaudio/slider"
                "custom/gap"
              ]
              ++ (lib.optionals (self.host.isModuleEnabled "bluetooth.bluetooth") [
                "custom/separator"
                "bluetooth"
              ])
              ++ [
                "custom/separator"
                "network"
                "custom/separator"
                "battery"
              ];
            };

            privacy = {
              icon-spacing = 4;
              icon-size = 18;
              transition-duration = 250;
              modules = [
                {
                  type = "screenshare";
                  tooltip = true;
                  tooltip-icon-size = 24;
                }
                {
                  type = "audio-out";
                  tooltip = true;
                  tooltip-icon-size = 24;
                }
                {
                  type = "audio-in";
                  tooltip = true;
                  tooltip-icon-size = 24;
                }
              ];
              ignore-monitor = true;
            };

            pulseaudio = {
              format = "{icon} {volume}%";
              format-muted = "󰖁 Muted";
              format-icons = {
                headphone = "󰋋";
                hands-free = "󰋎";
                headset = "󰋎";
                phone = "󰄜";
                portable = "󰄜";
                car = "󰄋";
                default = [
                  "󰕿"
                  "󰖀"
                  "󰕾"
                ];
              };
              on-click = "pavucontrol";
              on-click-right = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
            };

            "pulseaudio/slider" = {
              min = 0;
              max = 100;
              orientation = "horizontal";
            };

            bluetooth = {
              format = "󰂯 {status}";
              format-disabled = "󰂲 Off";
              format-off = "󰂲 Off";
              format-on = "󰂯 On";
              format-connected = "󰂱 {device_alias}";
              format-connected-battery = "󰂱 {device_alias} ({device_battery_percentage}%)";
              format-no-controller = "󰂲 Off";
              tooltip-format = "{controller_alias}\t{controller_address}\n\n{num_connections} connected";
              tooltip-format-connected = "{controller_alias}\t{controller_address}\n\n{num_connections} connected\n\n{device_enumerate}";
              tooltip-format-enumerate-connected = "{device_alias}\t{device_address}";
              tooltip-format-enumerate-connected-battery = "{device_alias}\t{device_address}\t({device_battery_percentage}%)";
              on-click = "blueman-manager";
            };

            network = {
              format-wifi = "󰤨 {signalStrength}%";
              format-ethernet = "{ifname}";
              format-linked = "󰤨 {ifname} (No IP)";
              format-disconnected = "󰤭 Disconnected";
              tooltip-format-wifi = "SSID: {essid}\nStrength: {signalStrength}%";
              on-click-right = "${self.settings.terminal} -e sh -c 'echo && echo -e \"\\033[1;32mip addr\\033[0m\" && echo && ip addr && echo && echo && echo && echo \"Press any key to exit...\" && read -n 1'";
            }
            // (
              if programsConfig ? installSystemSettings then
                {
                  on-click = "kcmshell6 kcm_networkmanagement";
                }
              else
                { }
            );

            battery = {
              states = {
                warning = 30;
                critical = 15;
              };
              format = "{icon} {capacity}%";
              format-charging = "󰂄 {capacity}%";
              format-plugged = "󰂄 {capacity}%";
              format-icons = [
                "󰂎"
                "󰁺"
                "󰁻"
                "󰁼"
                "󰁽"
                "󰁾"
                "󰁿"
                "󰂀"
                "󰂁"
                "󰂂"
                "󰁹"
              ];
            };

            tray = {
              icon-size = 23;
              show-passive-items = true;
              reverse-direction = true;
              spacing = 10;
            };
          };
        };

        style =
          let
            background = "#000000";
          in
          ''
            * {
              border: none;
              background-color: ${background};
              border-radius: 0px;
              min-height: 0;
              font-size: 22px;
            }

            window#waybar {
              background-color: ${background};
              transition-property: background-color;
              transition-duration: 0.5s;
            }

            .modules-left > widget:first-child > *:not(#workspacesgroup) {
              padding: 4px 5px 4px 5px;
              margin: 0px 5px 0px 4px;
              background-color: ${background};
            }

            #workspacesgroup {
              padding: 0px 0px 0px 0px;
              margin: 0px 2px 0px 2px;
              background-color: ${background};
            }

            .modules-center > widget > *,
            .modules-right > widget > *,
            .modules-left > widget:not(:first-child) > * {
              padding: 4px 5px 4px 5px;
              margin: 0px 0px 0px 0px;
              background-color: ${background};
            }

            #workspaces button {
              padding: 10px 4px 10px 4px;
              margin: 0 0px;
              background-color: ${background};
              border-radius: 0px;
              transition: all 0.3s ease;
            }

            #workspaces button * {
              background-color: ${background};
            }

            #workspaces .button {
              background-color: ${background};
            }

            #workspaces .button:hover {
              background-color: ${background};
            }

            #workspaces button.active, #workspaces button.focused, #workspaces button:hover {
              color: #ffffff;
            }

            #workspaces:hover {
              background-color: ${background};
            }

            #workspaces button:hover {
              color: #33dd44;
              background-color: rgba(200, 200, 200, 0.05);
            }

            #workspaces {
              border: none;
            }

            #workspaces, #clock,
            #cpu, #memory, #memory.swap, #disk, #disk.2, #systemd-failed-units, #load, #temperature,
            #privacy, #pulseaudio, #bluetooth, #network, #battery, #tray, #window, #window.app-id {
              padding: 12px 12px;
              background-color: ${background};
              border: none;
            }

            #cpu:hover, #memory:hover, #memory.swap:hover, #disk:hover, #disk.2:hover, #systemd-failed-units:hover, #load:hover, #temperature:hover,
            #privacy:hover, #pulseaudio:hover, #bluetooth:hover, #network:hover, #battery:hover {
              background-color: rgba(200, 200, 200, 0.05);
            }

            #workspacesgroup, #systemgroup, #windowgroup, #statusgroup, #timegroup, #traygroup {
              border: 1px solid rgba(0, 0, 0, 0);
              background-color: ${background};
              border: none;
            }

            #workspacesgroup:hover {
              background-color: ${background};
            }

            #systemgroup:hover, #windowgroup:hover, #statusgroup:hover, #timegroup:hover, #traygroup:hover {
              border: 1px solid #88bb44;
            }

            #tray menu {
              font-size: 14px;
            }

            #tray menu * {
              font-size: 14px;
            }

            #window, #window.app-id {
              min-width: 50px;
            }

            #window {
              color: #2299ff;
            }

            #window.app-id {
              color: #88bb44;
            }

            #battery.warning {
              color: #ffb86c;
            }

            #systemd-failed-units.ok {
              color: #50fa7b;
            }

            #systemd-failed-units.degraded {
              color: #ff5555;
            }

            #systemd-failed-units {
              color: #ff5555;
            }

            #battery.critical {
              color: #ff5555;
              animation: blink 1s linear infinite;
            }

            #custom-separator {
              color: #555555;
              margin: 0 1px;
              padding: 0 5px;
            }

            #custom-arrow {
              color: #88bb44;
              margin: 0 1px;
              padding: 0 5px;
              font-size: 24px;
            }

            #custom-gap {
              margin: 0 1px;
              padding: 0 1px;
            }

            #custom-nix {
              background-image: url("${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg");
              background-size: 42px;
              background-repeat: no-repeat;
              background-position: center;
              min-width: 40px;
              color: transparent;
              transition: all 0.3s ease;
            }

            #custom-nix:hover {
              background-color: rgba(100, 150, 255, 0.2);
              border: 1px solid #88bb44;
              opacity: 0.8;
            }

            window#waybar.empty #windowgroup {
              opacity: 0;
              min-width: 0;
              margin: 0;
              padding: 0;
            }


            @keyframes blink {
              to {
                background-color: rgba(255, 85, 85, 0.2);
              }
            }

            #pulseaudio-slider {
                padding: 0;
                margin: 0;
            }
            #pulseaudio-slider slider {
                min-height: 0px;
                min-width: 0px;
                opacity: 0;
                background-image: none;
                border: none;
                box-shadow: none;
                background-color: #339955;
            }
            #pulseaudio-slider trough {
                min-height: 10px;
                min-width: 120px;
                border-radius: 5px;
                background-color: #336644;
            }
            #pulseaudio-slider highlight {
                min-width: 10px;
                border-radius: 5px;
                background-color: #33ff44;
            }
          '';
      };
    };
}
