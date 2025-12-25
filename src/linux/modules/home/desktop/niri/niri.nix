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

  group = "desktop";
  input = "linux";
  namespace = "home";

  submodules = {
    linux = {
      browser = {
        qutebrowser = true;
      };
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
        waybar = {
          niri = true;
          output =
            if self.host ? displays && self.host.displays ? main then
              self.host.displays.main
            else if self.user ? displays && self.user.displays ? main then
              self.user.displays.main
            else
              null;
        };
        swaynotificationcenter = true;
        mako = false;
        swayidle = {
          turnOffMonitorsCommand = "${pkgs.niri}/bin/niri msg action power-off-monitors";
          turnOnMonitorsCommand = "${pkgs.niri}/bin/niri msg action power-on-monitors";
          package = pkgs.swaylock-effects;
          commandline = "swaylock --daemonize --clock --indicator --indicator-idle-visible --grace-no-mouse --effect-blur 8x2 --ring-color ${lib.removePrefix "#" self.theme.colors.main.backgrounds.primary.html}55 --indicator-radius 110 --effect-greyscale --submit-on-touch --screenshots --inside-wrong-color ${lib.removePrefix "#" self.theme.colors.main.backgrounds.primary.html} --text-wrong-color ${lib.removePrefix "#" self.theme.colors.semantic.error.html} --inside-ver-color ${lib.removePrefix "#" self.theme.colors.main.backgrounds.primary.html} --text-ver-color ${lib.removePrefix "#" self.theme.colors.semantic.success.html} --ring-ver-color ${lib.removePrefix "#" self.theme.colors.semantic.success.html} --ring-wrong-color ${lib.removePrefix "#" self.theme.colors.semantic.error.html} --ring-clear-color ${lib.removePrefix "#" self.theme.colors.main.base.blue.html} --text-clear-color ${lib.removePrefix "#" self.theme.colors.main.base.blue.html} --inside-clear-color ${lib.removePrefix "#" self.theme.colors.main.backgrounds.primary.html} --line-uses-inside --line-uses-ring";
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
        bongocat = true;
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
            desktopFile = "org.qutebrowser.qutebrowser.desktop";
          };
          videoPlayer = {
            name = "vlc";
            package = null;
            openCommand = "vlc";
            openFileCommand = "vlc";
            desktopFile = "vlc.desktop";
          };
          emailClient = {
            name = "thunderbird";
            package = null;
            openCommand = "thunderbird";
            openFileCommand = "thunderbird";
            desktopFile = "thunderbird.desktop";
          };
          calendar = {
            name = "thunderbird";
            package = null;
            openCommand = "thunderbird";
            openFileCommand = "thunderbird";
            desktopFile = "thunderbird.desktop";
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
      tmux = {
        tmux = true;
      };
      email = {
        thunderbird = true;
      };
      media = {
        vlc = true;
      };
    };
  };

  settings = {
    disableNewAppSwitcher = true;
    addRestartShortcut = false;
    screenshotBasePictureDir = "screenshots";
    mainDisplayScale = 1.0;
    secondaryDisplayScale = 1.0;
    applicationsToStart = [ ];
    delayedApplicationsToStart = [ ];
    activeColor = self.theme.colors.main.foregrounds.primary.html;
    inactiveColor = self.theme.colors.main.backgrounds.secondary.html;
    switchBackgroundOnWorkspaceChange = false;
    modKey = "Super";
    modKeyNested = "Alt";
    honorXDGActivation = true;
    deactivateUnfocusedWindows = true;
    appIdMapping = {
      "org.nx.scratchpad" = "com.mitchellh.ghostty";
      "org.nx.start-terminal" = "com.mitchellh.ghostty";
    };
    displayModes = {
      main = null;
      secondary = null;
    };
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
        "${self.user.settings.terminal} --class=org.nx.start-terminal -e tx"
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
          xdgConfig = self.getModuleConfig "xdg.user-dirs";
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

      home.file.".local/bin/restart-niri" = lib.mkIf self.settings.addRestartShortcut {
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

          if [[ -d "/tmp/.nx-deployment-lock" ]]; then
              notify-send "Power Menu" "Cannot access power options while NX deployment is running!" --icon=dialog-error
              exit 1
          fi

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

      home.file.".local/bin/tmux-session-manager" = lib.mkIf (self.common.isModuleEnabled "tmux.tmux") {
        executable = true;
        text = ''
          #!/usr/bin/env bash

          set -euo pipefail

          ${
            let
              tmuxConfig = self.common.getModuleConfig "tmux.tmux";
              allConfigs = tmuxConfig.tmuxinatorBaseConfigs // tmuxConfig.tmuxinatorConfigs;
              sessionNames = lib.attrNames allConfigs;
            in
            ''
              current_sessions=()
              if ${pkgs.tmux}/bin/tmux list-sessions 2>/dev/null; then
                while IFS=: read -r session_name _; do
                  current_sessions+=("$session_name")
                done < <(${pkgs.tmux}/bin/tmux list-sessions -F "#{session_name}" 2>/dev/null || true)
              fi

              session_list=""

              for session in "''${current_sessions[@]}"; do
                session_list+="● $session (running)"$'\n'
              done

              ${lib.concatStringsSep "\n" (
                map (name: ''
                  found=false
                  for current in "''${current_sessions[@]}"; do
                    if [[ "$current" == "${name}" ]]; then
                      found=true
                      break
                    fi
                  done
                  if [[ "$found" == "false" ]]; then
                    session_list+="○ ${name} (start)"$'\n'
                  fi
                '') sessionNames
              )}

              session_list+="+ New session"$'\n'

              if [[ -n "$session_list" ]]; then
                session_list=$(echo "$session_list" | head -c -1)
              fi

              selection=$(echo -e "$session_list" | fuzzel --dmenu --prompt="Tmux sessions: " --width=35)

              if [[ -z "$selection" ]]; then
                exit 0
              fi

              if [[ "$selection" == "+ New session" ]]; then
                exec ${self.user.settings.terminal} -e ${pkgs.tmux}/bin/tmux new-session
              elif [[ "$selection" =~ ^○\ (.+)\ \(start\)$ ]]; then
                session_name="''${BASH_REMATCH[1]}"
                exec ${self.user.settings.terminal} -e ${pkgs.tmuxinator}/bin/tmuxinator start "$session_name"
              elif [[ "$selection" =~ ^●\ (.+)\ \(running\)$ ]]; then
                session_name="''${BASH_REMATCH[1]}"
                exec ${self.user.settings.terminal} -e ${pkgs.tmux}/bin/tmux attach-session -t "$session_name"
              fi
            ''
          }
        '';
      };

      home.file.".local/bin/niri-window-switcher" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash

          set -euo pipefail

          get_icon_name() {
            local app_id="$1"
            local desktop_dir="/etc/profiles/per-user/${self.user.username}/share/applications"
            local desktop_file="$desktop_dir/$app_id.desktop"

            case "$app_id" in
              ${lib.concatStringsSep "\n              " (
                lib.mapAttrsToList (k: v: "\"${k}\") echo \"${v}\" ;;") self.settings.appIdMapping
              )}
              *)
                if [[ -f "$desktop_file" ]]; then
                  local icon
                  icon=$(grep -m1 "^Icon=" "$desktop_file" 2>/dev/null | cut -d'=' -f2)
                  if [[ -n "$icon" ]]; then
                    echo "$icon"
                    return
                  fi
                fi

                local found_file
                found_file=$(find "$desktop_dir" -maxdepth 1 -iname "$app_id.desktop" 2>/dev/null | head -1)
                if [[ -n "$found_file" ]]; then
                  local icon
                  icon=$(grep -m1 "^Icon=" "$found_file" 2>/dev/null | cut -d'=' -f2)
                  if [[ -n "$icon" ]]; then
                    echo "$icon"
                    return
                  fi
                fi

                echo "$app_id"
                ;;
            esac
          }

          window_ids=()
          window_titles=()

          while IFS=$'\t' read -r window_id app_id title; do
            window_ids+=("$window_id")
            icon_name=$(get_icon_name "$app_id")
            window_titles+=("$title\0icon\x1f$icon_name")
          done < <(niri msg --json windows | jq -r '.[] | [.id, .app_id, .title] | @tsv')

          result=$(printf "%b\n" "''${window_titles[@]}" | fuzzel --counter --dmenu --index)

          if [[ -n "$result" ]] && [[ "$result" != -1 ]]; then
            niri msg action focus-window --id "''${window_ids[$result]}"
          fi
        '';
      };

      home.file.".local/bin/niri-workspace-action" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash
          set -euo pipefail

          CHANGE_WALLPAPER=false
          ARGS=()
          while [[ $# -gt 0 ]]; do
            key="$1"

            case $key in
              --change-wallpaper)
                CHANGE_WALLPAPER=true
                shift
                ;;
              --*)
                echo "Unknown option: $1"
                exit 1
                ;;
              *)
                ARGS+=("$1")
                shift
                ;;
            esac
          done

          ${pkgs.niri}/bin/niri msg action "''${ARGS[@]}"

          ${
            if self.settings.switchBackgroundOnWorkspaceChange then
              ''
                if [[ "$CHANGE_WALLPAPER" == "true" && -x "$HOME/.local/bin/swaybg-next-wallpaper" ]]; then
                  "$HOME/.local/bin/swaybg-next-wallpaper"
                fi
              ''
            else
              ''
                if [[ "$CHANGE_WALLPAPER" == "true" && -x "$HOME/.local/bin/swaybg-reset-wallpaper" ]]; then
                  "$HOME/.local/bin/swaybg-reset-wallpaper"
                fi
              ''
          }
        '';
      };

      home.file.".local/bin/nop" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash
          exit 0
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

        nx-swaynotificationcenter =
          lib.mkIf (self.isModuleEnabled "desktop-modules.swaynotificationcenter")
            {
              Unit = {
                PartOf = [ "niri.service" ];
                After = [ "niri.service" ];
              };
            };

        mako = lib.mkIf (self.isModuleEnabled "desktop-modules.mako") {
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
      }
      //
        lib.optionalAttrs
          (
            let
              bongocatConfig = self.getModuleConfig "desktop-modules.bongocat";
            in
            bongocatConfig.event != null || bongocatConfig.keyboardName != null
          )
          {
            "nx-bongocat" = {
              Unit = {
                PartOf = [ "niri.service" ];
                After = [ "niri.service" ];
                Wants = [ ];
                Requisite = [ ];
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
        package = pkgs.niri;
        settings = {
          prefer-no-csd = true;
          hotkey-overlay.skip-at-startup = true;
          screenshot-path = screenshotPath;

          debug = lib.mkMerge [
            (lib.mkIf self.settings.honorXDGActivation {
              honor-xdg-activation-with-invalid-serial = [ ];
            })
            (lib.mkIf self.settings.deactivateUnfocusedWindows {
              deactivate-unfocused-windows = [ ];
            })
          ];

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
            backdrop-color = self.theme.colors.main.backgrounds.primary.html;
          };

          clipboard = {
            disable-primary = false;
          };

          layout = {
            background-color = self.theme.colors.main.backgrounds.primary.html;
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
                mode = lib.mkIf (self.settings.displayModes.main != null) self.settings.displayModes.main;
              };
            })
            (lib.mkIf (secondaryDisplay != null) {
              ${secondaryDisplay} = {
                scale = self.settings.secondaryDisplayScale;
                mode = lib.mkIf (self.settings.displayModes.secondary != null) self.settings.displayModes.secondary;
              };
            })
          ];

          workspaces = generateWorkspaces mainDisplay secondaryDisplay;

          binds =
            with config.lib.niri.actions;
            let
              basicKeys = [
                "A"
                "B"
                "C"
                "D"
                "E"
                "F"
                "G"
                "H"
                "I"
                "J"
                "K"
                "L"
                "M"
                "N"
                "O"
                "P"
                "Q"
                "R"
                "S"
                "T"
                "U"
                "V"
                "W"
                "X"
                "Y"
                "Z"
                "1"
                "2"
                "3"
                "4"
                "5"
                "6"
                "7"
                "8"
                "9"
                "0"
                "F1"
                "F2"
                "F3"
                "F4"
                "F5"
                "F6"
                "F7"
                "F8"
                "F9"
                "F10"
                "F11"
                "F12"
                "Escape"
                "Tab"
                "Space"
                "Return"
                "Backspace"
                "Delete"
                "Insert"
                "Home"
                "End"
                "Page_Up"
                "Page_Down"
                "Left"
                "Right"
                "Up"
                "Down"
                "Minus"
                "Equal"
                "Backslash"
                "Grave"
                "Semicolon"
                "Apostrophe"
                "Comma"
                "Period"
                "Slash"
                "BracketLeft"
                "BracketRight"
              ];

              modifierCombinations = [
                "Mod+"
                "Mod+Shift+"
                "Mod+Ctrl+"
                "Mod+Alt+"
                "Mod+Shift+Ctrl+"
                "Mod+Shift+Alt+"
                "Mod+Ctrl+Alt+"
                "Mod+Shift+Ctrl+Alt+"
              ];

              nopBindings = lib.listToAttrs (
                lib.flatten (
                  map (
                    key:
                    map (
                      modCombo: lib.nameValuePair "${modCombo}${key}" (lib.mkDefault { action = spawn-sh "nop"; })
                    ) modifierCombinations
                  ) basicKeys
                )
              );

              actualBindings = {
                "Alt+Tab" = lib.mkIf self.settings.disableNewAppSwitcher {
                  action = spawn-sh "nop";
                };

                "Alt+Shift+Tab" = lib.mkIf self.settings.disableNewAppSwitcher {
                  action = spawn-sh "nop";
                };

                "Mod+Return" = {
                  action = spawn-sh self.user.settings.terminal;
                  hotkey-overlay.title = "Apps:Terminal";
                };

                "Mod+Shift+Return" =
                  let
                    withSessionManager = self.common.isModuleEnabled "tmux.tmux";
                  in
                  {
                    action = spawn-sh "${
                      if withSessionManager then "tmux-session-manager" else "${self.user.settings.terminal} -e tx"
                    }";
                    hotkey-overlay.title =
                      if withSessionManager then "Apps:Tmux Session Manager" else "Apps:Tmux Main Session";
                  };

                "Mod+Space" = {
                  action = spawn-sh "fuzzel";
                  hotkey-overlay.title = "Apps:App launcher";
                };

                "Mod+Shift+Space" = {
                  action = spawn-sh "niri-window-switcher";
                  hotkey-overlay.title = "Apps:Window switcher";
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

                "Mod+Shift+Y" = {
                  action = spawn-sh "systemctl --user restart waybar.service";
                  hotkey-overlay.title = "UI:Restart waybar";
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

                "Mod+Ctrl+Tab" = {
                  action = spawn-sh "niri-workspace-action --change-wallpaper move-column-to-monitor-next";
                  hotkey-overlay.title = "Windows:Move column to next monitor";
                };

                "Mod+Shift+Down" = {
                  action = spawn-sh "niri-workspace-action move-column-to-workspace-down";
                  hotkey-overlay.title = "Windows:Move column down";
                };

                "Mod+Shift+Up" = {
                  action = spawn-sh "niri-workspace-action move-column-to-workspace-up";
                  hotkey-overlay.title = "Windows:Move column up";
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

                "Mod+R" = {
                  action = reset-window-height;
                  hotkey-overlay.title = "Windows:Reset height";
                };

                "Mod+Shift+Tab" = {
                  action = spawn-sh "niri-workspace-action --change-wallpaper focus-monitor-next";
                  hotkey-overlay.title = "Monitor:Cycle monitor focus";
                };

                "Mod+D" = {
                  action = spawn-sh "niri-workspace-action focus-workspace-down";
                  hotkey-overlay.title = "Workspace:Workspace down";
                };

                "Mod+U" = {
                  action = spawn-sh "niri-workspace-action focus-workspace-up";
                  hotkey-overlay.title = "Workspace:Workspace up";
                };

                "Mod+Down" = {
                  action = spawn-sh "niri-workspace-action focus-workspace-down";
                  hotkey-overlay.title = "Workspace:Workspace down";
                };

                "Mod+Up" = {
                  action = spawn-sh "niri-workspace-action focus-workspace-up";
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
                  action = spawn-sh "niri-workspace-action focus-workspace-down";
                  cooldown-ms = 150;
                };

                "Mod+Shift+WheelScrollUp" = {
                  action = spawn-sh "niri-workspace-action focus-workspace-up";
                  cooldown-ms = 150;
                };

                "Mod+1" = {
                  action = spawn-sh "niri-workspace-action focus-workspace 1";
                  hotkey-overlay.title = "Workspace:Workspace 1";
                };

                "Mod+2" = {
                  action = spawn-sh "niri-workspace-action focus-workspace 2";
                  hotkey-overlay.title = "Workspace:Workspace 2";
                };

                "Mod+3" = {
                  action = spawn-sh "niri-workspace-action focus-workspace 3";
                  hotkey-overlay.title = "Workspace:Workspace 3";
                };

                "Mod+4" = {
                  action = spawn-sh "niri-workspace-action focus-workspace 4";
                  hotkey-overlay.title = "Workspace:Workspace 4";
                };

                "Mod+5" = {
                  action = spawn-sh "niri-workspace-action focus-workspace 5";
                  hotkey-overlay.title = "Workspace:Workspace 5";
                };

                "Mod+6" = {
                  action = spawn-sh "niri-workspace-action focus-workspace 6";
                  hotkey-overlay.title = "Workspace:Workspace 6";
                };

                "Mod+7" = {
                  action = spawn-sh "niri-workspace-action focus-workspace 7";
                  hotkey-overlay.title = "Workspace:Workspace 7";
                };

                "Mod+8" = {
                  action = spawn-sh "niri-workspace-action focus-workspace 8";
                  hotkey-overlay.title = "Workspace:Workspace 8";
                };

                "Mod+9" = {
                  action = spawn-sh "niri-workspace-action focus-workspace 9";
                  hotkey-overlay.title = "Workspace:Workspace 9";
                };

                "Mod+S" = {
                  action = spawn-sh "niri-workspace-action focus-workspace scratch";
                  hotkey-overlay.title = "Workspace:Scratchpad";
                };

                "Mod+Shift+D" = {
                  action = spawn-sh "niri-workspace-action move-column-to-workspace-down";
                  hotkey-overlay.title = "Windows:Move column down";
                };

                "Mod+Shift+U" = {
                  action = spawn-sh "niri-workspace-action move-column-to-workspace-up";
                  hotkey-overlay.title = "Windows:Move column up";
                };

                "Mod+Shift+1" = {
                  action = spawn-sh "niri-workspace-action move-column-to-workspace 1";
                  hotkey-overlay.title = "Windows:Move to workspace 1";
                };

                "Mod+Shift+2" = {
                  action = spawn-sh "niri-workspace-action move-column-to-workspace 2";
                  hotkey-overlay.title = "Windows:Move to workspace 2";
                };

                "Mod+Shift+3" = {
                  action = spawn-sh "niri-workspace-action move-column-to-workspace 3";
                  hotkey-overlay.title = "Windows:Move to workspace 3";
                };

                "Mod+Shift+4" = {
                  action = spawn-sh "niri-workspace-action move-column-to-workspace 4";
                  hotkey-overlay.title = "Windows:Move to workspace 4";
                };

                "Mod+Shift+5" = {
                  action = spawn-sh "niri-workspace-action move-column-to-workspace 5";
                  hotkey-overlay.title = "Windows:Move to workspace 5";
                };

                "Mod+Shift+6" = {
                  action = spawn-sh "niri-workspace-action move-column-to-workspace 6";
                  hotkey-overlay.title = "Windows:Move to workspace 6";
                };

                "Mod+Shift+7" = {
                  action = spawn-sh "niri-workspace-action move-column-to-workspace 7";
                  hotkey-overlay.title = "Windows:Move to workspace 7";
                };

                "Mod+Shift+8" = {
                  action = spawn-sh "niri-workspace-action move-column-to-workspace 8";
                  hotkey-overlay.title = "Windows:Move to workspace 8";
                };

                "Mod+Shift+9" = {
                  action = spawn-sh "niri-workspace-action move-column-to-workspace 9";
                  hotkey-overlay.title = "Windows:Move to workspace 9";
                };

                "Mod+Shift+S" = {
                  action = spawn-sh "niri-workspace-action move-column-to-workspace scratch";
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

                "Mod+Shift+Backspace" = {
                  action = toggle-window-floating;
                  hotkey-overlay.title = "Windows:Toggle floating for window";
                };

                "Mod+Backspace" = {
                  action = switch-focus-between-floating-and-tiling;
                  hotkey-overlay.title = "Windows:Switch float/tile view";
                };

                "Mod+Ctrl+Q" = {
                  action = spawn "loginctl" "lock-session";
                  hotkey-overlay.title = "System:Lock screen";
                };

                "Mod+Ctrl+Alt+Backspace" = {
                  action = spawn-sh "power-menu";
                  hotkey-overlay.title = "System:Power menu";
                };

                "Mod+Ctrl+Alt+R" = lib.mkIf self.settings.addRestartShortcut {
                  action = spawn-sh "restart-niri";
                  hotkey-overlay.title = "System:Restart niri";
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

                "Mod+Ctrl+Alt+Return" = {
                  action = spawn-sh "niri-scratchpad --app-id org.nx.scratchpad --all-windows --spawn scratchpad-terminal";
                  hotkey-overlay.title = "Apps:Scratchpad term";
                };
              };
            in
            nopBindings // actualBindings;

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
                proportion = 0.33;
              };
            }
            {
              matches = [ { app-id = "org.nx.start-terminal"; } ];
              default-column-width = {
                proportion = 0.47;
              };
              open-on-workspace = "1";
              open-focused = true;
            }
            {
              matches = [ { app-id = "org.nx.scratchpad"; } ];
              default-column-width = {
                proportion = 0.40;
              };
              default-window-height = {
                fixed = 500;
              };
              open-on-workspace = "scratch";
              open-floating = true;
              open-focused = false;
            }
            {
              matches = [ { app-id = "org.pulseaudio.pavucontrol"; } ];
              default-column-width = {
                proportion = 0.5;
              };
            }
          ];
        };
      };
    };
}
