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
  name = "niri";

  submodules = {
    linux = {
      storage = {
        auto-mount = true;
      };
      xdg = {
        cleanup-desktop = true;
      };
      desktop = {
        common = true;
      };
      desktop-modules = {
        bemoji = true;
        fuzzel = {
          terminal = "${pkgs.${self.user.settings.terminal}}/bin/${self.user.settings.terminal} -e";
        };
        waybar = {
          terminal = "ghostty";
          niri = true;
          output =
            if self.host ? displays && self.host.displays ? main then
              self.host.displays.main
            else if self.user ? displays && self.user.displays ? main then
              self.user.displays.main
            else
              null;
        };
        mako = true;
        swayidle = {
          turnOffMonitorsCommand = "${pkgs.niri}/bin/niri msg action power-off-monitors";
          turnOnMonitorsCommand = "${pkgs.niri}/bin/niri msg action power-on-monitors";
          package = pkgs.swaylock-effects;
          commandline = "swaylock --daemonize --clock --indicator --indicator-idle-visible --grace-no-mouse --effect-blur 8x2 --ring-color 00000055 --indicator-radius 110 --effect-greyscale --submit-on-touch --screenshots --inside-wrong-color 000000 --text-wrong-color ff0000 --inside-ver-color 000000 --text-ver-color 00ff00 --ring-ver-color 00ff00 --ring-wrong-color ff0000 --ring-clear-color 0000ff --text-clear-color 0000ff --inside-clear-color 000000 --line-uses-inside --line-uses-ring";
        };
        swaylock = {
          useEffects = true;
        };
        swaybg = true;
        nwg-wrapper = {
          usedTerminal = self.user.settings.terminal;
          niriKeybindings = true;
        };
        wlsunset = true;
        programs = {
          terminal = {
            name = self.user.settings.terminal;
            package = null;
            openCommand = self.user.settings.terminal;
            openFileCommand = self.user.settings.terminal + " -e";
            desktopFile = "com.mitchellh.ghostty.desktop";
          };
          webBrowser = {
            name = "qutebrowser";
            package = null;
            openCommand = "qutebrowser";
            openFileCommand = "qutebrowser";
          };
          installOfficeSuite = true;
          installSystemSettings = true;
        };
        clipboard-persistence = true;
      };
      terminal = {
        "${self.user.settings.terminal}" = true;
      };
    };
    common = {
      terminal = {
        kitty = true; # Fallback terminal
      };
      browser = {
        qutebrowser = true;
      };
    };
  };

  defaults = {
    screenshotBasePictureDir = "screenshots";
    mainDisplayScale = 1.0;
    secondaryDisplayScale = 1.0;
    applicationsToStart = [ ];
    delayedApplicationsToStart = [ ];
    activeColor = "#88cc66";
    inactiveColor = "#222233";
    modKey = "Super";
    modKeyNested = "Alt";
  };

  assertions = [
    {
      assertion =
        (self.user.isStandalone or false) || (self.host.isModuleEnabled or (x: false)) "desktop.niri";
      message = "Requires linux.desktop.niri nixos module to be enabled!";
    }
    {
      assertion = (self.host.displays.main or self.user.displays.main or null) != null;
      message = "Requires host.displays.main or user.displays.main (for standalone) to be configured!";
    }
    {
      assertion = self.user.settings.terminal != null;
      message = "user.settings.terminal is not set!";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    let
      isStandalone = self.user.isStandalone;
      mainDisplay = self.host.displays.main or self.user.displays.main or null;
      secondaryDisplay = self.host.displays.secondary or self.user.displays.secondary or null;
      programsConfig = self.getModuleConfig "desktop-modules.programs";
      requiredApps = [
        "${self.user.settings.terminal} --class=org.nx.start-terminal"
        "${self.user.settings.terminal} --class=org.nx.scratchpad"
      ];
      delayedRequiredApps = [ ];
      stylixConfig =
        if isStandalone then
          self.common.getModuleConfig "style.stylix"
        else
          self.common.host.getModuleConfig "style.stylix";
      activeColor = self.settings.activeColor;
      inactiveColor = self.settings.inactiveColor;

      screenshotPath =
        let
          xdgConfig = self.common.getModuleConfig "xdg.user-dirs";
          picturesDir =
            if xdgConfig != { } && xdgConfig ? pictures then
              "${self.user.home}/${xdgConfig.pictures}"
            else
              "${self.user.home}/Pictures";
        in
        "${picturesDir}/${self.settings.screenshotBasePictureDir}/%Y_%m_%d_%H%M%S.png";

      screenshotDir = builtins.dirOf screenshotPath;

      generateStartupCommands = apps: map (app: { sh = "sleep 1 && uwsm app -- ${app}"; }) apps;

      generateDelayedStartupCommands = apps: map (app: { sh = "sleep 6 && uwsm app -- ${app}"; }) apps;

      startupApps = requiredApps ++ self.settings.applicationsToStart;
      delayedStartupApps = delayedRequiredApps ++ self.settings.delayedApplicationsToStart;

      generateWorkspaces =
        main: secondary:
        if main == null && secondary == null then
          {
            "1" = {
              name = "1";
            };
            "2" = {
              name = "2";
            };
            "3" = {
              name = "3";
            };
            "4" = {
              name = "4";
            };
            "5" = {
              name = "5";
            };
            "6" = {
              name = "6";
            };
            "7" = {
              name = "7";
            };
            "8" = {
              name = "8";
            };
            "9" = {
              name = "9";
            };
            "10" = {
              name = "10";
            };
            "scratch" = {
              name = "scratch";
            };
          }
        else if secondary == null then
          {
            "1" = {
              name = "1";
              open-on-output = main;
            };
            "2" = {
              name = "2";
              open-on-output = main;
            };
            "3" = {
              name = "3";
              open-on-output = main;
            };
            "4" = {
              name = "4";
              open-on-output = main;
            };
            "5" = {
              name = "5";
              open-on-output = main;
            };
            "6" = {
              name = "6";
              open-on-output = main;
            };
            "7" = {
              name = "7";
              open-on-output = main;
            };
            "8" = {
              name = "8";
              open-on-output = main;
            };
            "9" = {
              name = "9";
              open-on-output = main;
            };
            "10" = {
              name = "10";
              open-on-output = main;
            };
            "scratch" = {
              name = "scratch";
              open-on-output = main;
            };
          }
        else
          {
            "1" = {
              name = "1";
              open-on-output = main;
            };
            "2" = {
              name = "2";
              open-on-output = main;
            };
            "3" = {
              name = "3";
              open-on-output = main;
            };
            "4" = {
              name = "4";
              open-on-output = main;
            };
            "5" = {
              name = "5";
              open-on-output = main;
            };
            "6" = {
              name = "6";
              open-on-output = main;
            };
            "7" = {
              name = "7";
              open-on-output = secondary;
            };
            "8" = {
              name = "8";
              open-on-output = secondary;
            };
            "9" = {
              name = "9";
              open-on-output = secondary;
            };
            "10" = {
              name = "10";
              open-on-output = secondary;
            };
            "scratch" = {
              name = "scratch";
              open-on-output = main;
            };
          };
    in
    {
      home.packages = [ pkgs.jq ];

      home.file.".local/bin/niri-scratchpad" = {
        source = self.file "niri-scratchpad/niri-scratchpad.sh";
        executable = true;
      };

      home.file.".local/bin/restart-niri" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash

          choice=$(echo -e "Yes\nNo" | fuzzel --dmenu --prompt "Restart Niri session? " --width=25 --lines=2)

          case "$choice" in
            "Yes")
              systemctl --user restart niri.service
              ;;
            "No"|"")
              exit 0
              ;;
          esac
        '';
      };

      home.file.".local/bin/power-menu" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash

          # Power menu using fuzzel
          # Usage: power-menu.sh

          set -euo pipefail

          action=$(echo -e "Poweroff\nReboot" | fuzzel --dmenu --prompt="Power actions: " --width=25 --lines=2)

          if [[ -z "$action" ]]; then
              exit 0
          fi

          declare -A commands=(
              ["Poweroff"]="systemctl poweroff"
              ["Reboot"]="systemctl reboot"
          )

          confirm=$(echo -e "Yes\nNo" | fuzzel --dmenu --prompt="$action? " --width=20 --lines=2)

          if [[ "$confirm" == "Yes" ]]; then
              ''${commands[$action]}
          fi
        '';
      };

      home.file.".local/bin/scratchpad-terminal" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash
          exec ${self.user.settings.terminal} --class=org.nx.scratchpad
        '';
      };

      systemd.user.services = {
        waybar = {
          Unit = {
            PartOf = [ "niri.service" ];
            After = [ "niri.service" ];
          };
        };

        "nx-swaybg" = {
          Unit = {
            PartOf = [ "niri.service" ];
            After = [ "niri.service" ];
          };
        };

        swayidle = {
          Unit = {
            PartOf = [ "niri.service" ];
            After = [ "niri.service" ];
          };
        };

        mako = {
          Unit = {
            PartOf = [ "niri.service" ];
            After = [ "niri.service" ];
          };
        };

        "nx-nwg-wrapper-1" = {
          Unit = {
            PartOf = [ "niri.service" ];
            After = [ "niri.service" ];
          };
        };

        "nx-nwg-wrapper-2" = {
          Unit = {
            PartOf = [ "niri.service" ];
            After = [ "niri.service" ];
          };
        };

        "nx-nwg-wrapper-3" = {
          Unit = {
            PartOf = [ "niri.service" ];
            After = [ "niri.service" ];
          };
        };

        wlsunset = {
          Unit = {
            PartOf = [ "niri.service" ];
            After = [ "niri.service" ];
          };
        };

        clipman = {
          Unit = {
            PartOf = [ "niri.service" ];
            After = [ "niri.service" ];
          };
        };
      };

      programs.niri = {
        package = pkgs-unstable.niri;
        settings = {
          prefer-no-csd = true;
          hotkey-overlay.skip-at-startup = true;
          screenshot-path = screenshotPath;

          spawn-at-startup =
            (generateStartupCommands startupApps) ++ (generateDelayedStartupCommands delayedStartupApps);

          input = {
            mod-key = self.settings.modKey;
            mod-key-nested = self.settings.modKeyNested;
            workspace-auto-back-and-forth = true;

            keyboard = {
              xkb = {
                layout = self.host.settings.system.keymap.x11.layout;
                variant = self.host.settings.system.keymap.x11.variant;
                options = self.host.settings.system.keymap.x11.options;
              };
              repeat-delay = 600;
              repeat-rate = 25;
            };

            mouse = {
              natural-scroll = true;
              accel-speed = 0.0;
              accel-profile = "adaptive";
            };

            touchpad = {
              natural-scroll = true;
              accel-speed = 0.0;
              accel-profile = "adaptive";
            };

            warp-mouse-to-focus = {
              enable = false;
            };

            focus-follows-mouse = {
              enable = false;
            };
          };

          xwayland-satellite = {
            path = "xwayland-satellite";
          };

          cursor = {
            hide-when-typing = true;
          }
          // (
            if stylixConfig.cursor != null then
              {
                theme = lib.last (lib.splitString "/" stylixConfig.cursor.style);
                size = stylixConfig.cursor.size;
              }
            else
              { }
          );

          overview = {
            zoom = 0.93;
            backdrop-color = "#000000";
          };

          clipboard = {
            disable-primary = true;
          };

          layout = {
            gaps = 18;
            preset-column-widths = [
              { proportion = 0.25; }
              { proportion = 0.33; }
              { proportion = 0.5; }
              { proportion = 0.67; }
              { proportion = 0.75; }
              { proportion = 1.0; }
            ];
            preset-window-heights = [
              { proportion = 0.25; }
              { proportion = 0.33; }
              { proportion = 0.5; }
              { proportion = 0.67; }
              { proportion = 0.75; }
              { proportion = 1.0; }
            ];
            center-focused-column = "on-overflow";
            always-center-single-column = true;
            border = {
              width = 4;
              active.color = activeColor;
              inactive.color = inactiveColor;
            };
            focus-ring = {
              enable = false;
            };
          };

          outputs = lib.mkMerge [
            (lib.mkIf (mainDisplay != null) {
              ${mainDisplay} = {
                focus-at-startup = true;
                scale = self.settings.mainDisplayScale;
              };
            })
            (lib.mkIf (secondaryDisplay != null) {
              ${secondaryDisplay} = {
                scale = self.settings.secondaryDisplayScale;
              };
            })
          ];

          workspaces = generateWorkspaces mainDisplay secondaryDisplay;

          binds = with config.lib.niri.actions; {

            "Mod+Return" = {
              action = spawn-sh self.user.settings.terminal;
              hotkey-overlay.title = "Apps:Terminal";
            };

            "Mod+Space" = {
              action = spawn-sh "fuzzel";
              hotkey-overlay.title = "Apps:App launcher";
            };

            "Mod+Q" = {
              action = close-window;
              hotkey-overlay.title = "Windows:Close window";
            };

            "Mod+H" = {
              action = focus-column-left;
              hotkey-overlay.title = "Focus:Focus left";
            };

            "Mod+J" = {
              action = focus-window-down;
              hotkey-overlay.title = "Focus:Focus down";
            };

            "Mod+K" = {
              action = focus-window-up;
              hotkey-overlay.title = "Focus:Focus up";
            };

            "Mod+L" = {
              action = focus-column-right;
              hotkey-overlay.title = "Focus:Focus right";
            };

            "Mod+Home" = {
              action = focus-column-first;
              hotkey-overlay.title = "Focus:Focus first";
            };

            "Mod+End" = {
              action = focus-column-last;
              hotkey-overlay.title = "Focus:Focus last";
            };

            "Mod+Page_Up" = {
              action = focus-column-first;
              hotkey-overlay.title = "Focus:Focus first";
            };

            "Mod+Page_Down" = {
              action = focus-column-last;
              hotkey-overlay.title = "Focus:Focus last";
            };

            "Print" = {
              action = screenshot { show-pointer = false; };
              hotkey-overlay.title = "Screenshot:Screenshot";
            };

            "Shift+Print" = {
              action = screenshot-window { write-to-disk = true; };
              hotkey-overlay.title = "Screenshot:Window screenshot";
            };

            "Mod+P" = {
              action = screenshot { show-pointer = false; };
              hotkey-overlay.title = "Screenshot:Screenshot";
            };

            "Mod+Shift+P" = {
              action = screenshot-window { write-to-disk = true; };
              hotkey-overlay.title = "Screenshot:Window screenshot";
            };

            "Mod+Ctrl+P" = {
              action = spawn-sh "${programsConfig.fileBrowser.openFileCommand} '${screenshotDir}'";
              hotkey-overlay.title = "Screenshot:Open screenshots folder";
            };

            "Mod+O" = {
              action = toggle-overview;
              hotkey-overlay.title = "Windows:Toggle overview";
            };

            "Mod+Y" = {
              action = spawn-sh "systemctl --user kill -s SIGUSR1 waybar.service";
              hotkey-overlay.title = "UI:Toggle waybar visibility";
            };

            "Mod+Tab" = {
              action = focus-workspace-previous;
              hotkey-overlay.title = "Workspace:Toggle workspaces";
            };

            "Mod+Shift+H" = {
              action = consume-or-expel-window-left;
              hotkey-overlay.title = "Windows:Move window left";
            };

            "Mod+Shift+J" = {
              action = move-window-down;
              hotkey-overlay.title = "Windows:Move window down";
            };

            "Mod+Shift+K" = {
              action = move-window-up;
              hotkey-overlay.title = "Windows:Move window up";
            };

            "Mod+Shift+L" = {
              action = consume-or-expel-window-right;
              hotkey-overlay.title = "Windows:Move window right";
            };

            "Mod+Shift+Left" = {
              action = consume-or-expel-window-left;
              hotkey-overlay.title = "Windows:Move window left";
            };

            "Mod+Shift+Down" = {
              action = move-window-down;
              hotkey-overlay.title = "Windows:Move window down";
            };

            "Mod+Shift+Up" = {
              action = move-window-up;
              hotkey-overlay.title = "Windows:Move window up";
            };

            "Mod+Shift+Right" = {
              action = consume-or-expel-window-right;
              hotkey-overlay.title = "Windows:Move window right";
            };

            "Mod+Ctrl+H" = {
              action = switch-preset-column-width-back;
              hotkey-overlay.title = "Windows:Size left";
            };

            "Mod+Ctrl+J" = {
              action = switch-preset-window-height-back;
              hotkey-overlay.title = "Windows:Size down";
            };

            "Mod+Ctrl+K" = {
              action = switch-preset-window-height;
              hotkey-overlay.title = "Windows:Size up";
            };

            "Mod+Ctrl+L" = {
              action = switch-preset-column-width;
              hotkey-overlay.title = "Windows:Size right";
            };

            "Mod+Ctrl+Left" = {
              action = switch-preset-column-width-back;
              hotkey-overlay.title = "Windows:Size left";
            };

            "Mod+Ctrl+Down" = {
              action = switch-preset-window-height-back;
              hotkey-overlay.title = "Windows:Size down";
            };

            "Mod+Ctrl+Up" = {
              action = switch-preset-window-height;
              hotkey-overlay.title = "Windows:Size up";
            };

            "Mod+Ctrl+Right" = {
              action = switch-preset-column-width;
              hotkey-overlay.title = "Windows:Size right";
            };

            "Mod+R" = {
              action = reset-window-height;
              hotkey-overlay.title = "Windows:Reset height";
            };

            "Mod+Left" = {
              action = focus-monitor-left;
              hotkey-overlay.title = "Monitor:Monitor left";
            };

            "Mod+Right" = {
              action = focus-monitor-right;
              hotkey-overlay.title = "Monitor:Monitor right";
            };

            "Mod+D" = {
              action = focus-workspace-down;
              hotkey-overlay.title = "Workspace:Workspace down";
            };

            "Mod+U" = {
              action = focus-workspace-up;
              hotkey-overlay.title = "Workspace:Workspace up";
            };

            "Mod+Down" = {
              action = focus-workspace-down;
              hotkey-overlay.title = "Workspace:Workspace down";
            };

            "Mod+Up" = {
              action = focus-workspace-up;
              hotkey-overlay.title = "Workspace:Workspace up";
            };

            "Mod+WheelScrollDown" = {
              action = focus-column-left;
              cooldown-ms = 150;
            };

            "Mod+WheelScrollUp" = {
              action = focus-column-right;
              cooldown-ms = 150;
            };

            "Mod+Shift+WheelScrollDown" = {
              action = focus-workspace-down;
              cooldown-ms = 150;
            };

            "Mod+Shift+WheelScrollUp" = {
              action = focus-workspace-up;
              cooldown-ms = 150;
            };

            "Mod+1" = {
              action = focus-workspace "1";
              hotkey-overlay.title = "Workspace:Workspace 1";
            };

            "Mod+2" = {
              action = focus-workspace "2";
              hotkey-overlay.title = "Workspace:Workspace 2";
            };

            "Mod+3" = {
              action = focus-workspace "3";
              hotkey-overlay.title = "Workspace:Workspace 3";
            };

            "Mod+4" = {
              action = focus-workspace "4";
              hotkey-overlay.title = "Workspace:Workspace 4";
            };

            "Mod+5" = {
              action = focus-workspace "5";
              hotkey-overlay.title = "Workspace:Workspace 5";
            };

            "Mod+6" = {
              action = focus-workspace "6";
              hotkey-overlay.title = "Workspace:Workspace 6";
            };

            "Mod+7" = {
              action = focus-workspace "7";
              hotkey-overlay.title = "Workspace:Workspace 7";
            };

            "Mod+8" = {
              action = focus-workspace "8";
              hotkey-overlay.title = "Workspace:Workspace 8";
            };

            "Mod+9" = {
              action = focus-workspace "9";
              hotkey-overlay.title = "Workspace:Workspace 9";
            };

            "Mod+0" = {
              action = focus-workspace "10";
              hotkey-overlay.title = "Workspace:Workspace 10";
            };

            "Mod+S" = {
              action = focus-workspace "scratch";
              hotkey-overlay.title = "Workspace:Scratchpad";
            };

            "Mod+Shift+D" = {
              action = move-column-to-workspace-down;
              hotkey-overlay.title = "Windows:Move workspace down";
            };

            "Mod+Shift+U" = {
              action = move-column-to-workspace-up;
              hotkey-overlay.title = "Windows:Move workspace up";
            };

            "Mod+Shift+1" = {
              action = move-column-to-index 0;
              hotkey-overlay.title = "Windows:Move to workspace 1";
            };

            "Mod+Shift+2" = {
              action = move-column-to-index 1;
              hotkey-overlay.title = "Windows:Move to workspace 2";
            };

            "Mod+Shift+3" = {
              action = move-column-to-index 2;
              hotkey-overlay.title = "Windows:Move to workspace 3";
            };

            "Mod+Shift+4" = {
              action = move-column-to-index 3;
              hotkey-overlay.title = "Windows:Move to workspace 4";
            };

            "Mod+Shift+5" = {
              action = move-column-to-index 4;
              hotkey-overlay.title = "Windows:Move to workspace 5";
            };

            "Mod+Shift+6" = {
              action = move-column-to-index 5;
              hotkey-overlay.title = "Windows:Move to workspace 6";
            };

            "Mod+Shift+7" = {
              action = move-column-to-index 6;
              hotkey-overlay.title = "Windows:Move to workspace 7";
            };

            "Mod+Shift+8" = {
              action = move-column-to-index 7;
              hotkey-overlay.title = "Windows:Move to workspace 8";
            };

            "Mod+Shift+9" = {
              action = move-column-to-index 8;
              hotkey-overlay.title = "Windows:Move to workspace 9";
            };

            "Mod+Shift+0" = {
              action = move-column-to-index 9;
              hotkey-overlay.title = "Windows:Move to workspace 10";
            };

            "Mod+Shift+S" = {
              action = move-column-to-index 10;
              hotkey-overlay.title = "Windows:Move to scratchpad";
            };

            "Mod+F" = {
              action = maximize-column;
              hotkey-overlay.title = "Windows:Maximize column";
            };

            "Mod+Shift+F" = {
              action = fullscreen-window;
              hotkey-overlay.title = "Windows:Fullscreen";
            };

            "Mod+G" = {
              action = center-column;
              hotkey-overlay.title = "Windows:Center column";
            };

            "Mod+Backspace" = {
              action = toggle-window-floating;
              hotkey-overlay.title = "Windows:Toggle floating";
            };

            "Mod+Shift+Backspace" = {
              action = switch-focus-between-floating-and-tiling;
              hotkey-overlay.title = "Windows:Switch float/tile";
            };

            "Mod+Ctrl+Q" = {
              action = spawn "loginctl" "lock-session";
              hotkey-overlay.title = "System:Lock screen";
            };

            "Ctrl+Alt+Mod+Backspace" = {
              action = spawn-sh "power-menu";
              hotkey-overlay.title = "System:Power menu";
            };

            "Ctrl+Mod+Alt+R" = {
              action = spawn-sh "restart-niri";
              hotkey-overlay.title = "System:Restart niri";
            };

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

            "XF86AudioRaiseVolume" = {
              action = spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+";
              hotkey-overlay.title = "Audio:Volume up";
            };

            "XF86AudioLowerVolume" = {
              action = spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-";
              hotkey-overlay.title = "Audio:Volume down";
            };

            "XF86AudioMute" = {
              action = spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle";
              hotkey-overlay.title = "Audio:Mute toggle";
            };

            "Mod+Equal" = {
              action = spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+";
              hotkey-overlay.title = "Audio:Volume up";
            };

            "Mod+Minus" = {
              action = spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-";
              hotkey-overlay.title = "Audio:Volume down";
            };

            "Mod+Shift+Minus" = {
              action = spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle";
              hotkey-overlay.title = "Audio:Mute toggle";
            };

            "Mod+Shift+Equal" = {
              action = spawn "pavucontrol";
              hotkey-overlay.title = "Audio:Audio control";
            };

            "Ctrl+Mod+Alt+Return" = {
              action = spawn-sh "niri-scratchpad --app-id org.nx.scratchpad --spawn scratchpad-terminal";
              hotkey-overlay.title = "Apps:Scratchpad term";
            };
          };

          animations = {
            slowdown = 2.5;

            workspace-switch = {
              kind = {
                spring = {
                  damping-ratio = 1.0;
                  stiffness = 1000;
                  epsilon = 0.0001;
                };
              };
            };

            window-open = {
              kind = {
                easing = {
                  duration-ms = 150;
                  curve = "ease-out-expo";
                };
              };
            };

            window-close = {
              kind = {
                easing = {
                  duration-ms = 150;
                  curve = "ease-out-quad";
                };
              };
            };

            horizontal-view-movement = {
              kind = {
                spring = {
                  damping-ratio = 1.0;
                  stiffness = 800;
                  epsilon = 0.0001;
                };
              };
            };

            window-movement = {
              kind = {
                spring = {
                  damping-ratio = 1.0;
                  stiffness = 800;
                  epsilon = 0.0001;
                };
              };
            };

            window-resize = {
              kind = {
                spring = {
                  damping-ratio = 1.0;
                  stiffness = 800;
                  epsilon = 0.0001;
                };
              };
            };

            config-notification-open-close = {
              kind = {
                spring = {
                  damping-ratio = 0.6;
                  stiffness = 1000;
                  epsilon = 0.001;
                };
              };
            };

            exit-confirmation-open-close = {
              kind = {
                spring = {
                  damping-ratio = 0.6;
                  stiffness = 500;
                  epsilon = 0.01;
                };
              };
            };

            screenshot-ui-open = {
              kind = {
                easing = {
                  duration-ms = 200;
                  curve = "ease-out-quad";
                };
              };
            };

            overview-open-close = {
              kind = {
                spring = {
                  damping-ratio = 1.0;
                  stiffness = 800;
                  epsilon = 0.0001;
                };
              };
            };
          };

          window-rules = [
            {
              matches = [ { app-id = "com.mitchellh.ghostty"; } ];
              default-column-width = {
                proportion = 0.35;
              };
            }
            {
              matches = [ { app-id = "org.nx.start-terminal"; } ];
              default-column-width = {
                proportion = 0.35;
              };
              open-on-workspace = "1";
              open-focused = true;
            }
            {
              matches = [ { app-id = "org.nx.scratchpad"; } ];
              default-column-width = {
                proportion = 0.35;
              };
              default-window-height = {
                fixed = 500;
              };
              open-on-workspace = "scratch";
              open-floating = true;
              open-focused = false;
            }
          ];
        };
      };
    };
}
