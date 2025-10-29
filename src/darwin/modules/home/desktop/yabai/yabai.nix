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
  name = "yabai";

  group = "desktop";
  input = "darwin";
  namespace = "home";

  submodules = {
    darwin = {
      software = {
        homebrew = true;
      };
    };
  };

  assertions = [
    {
      assertion = !self.isModuleEnabled "desktop.amethyst";
      message = "Yabai and amethyst are mutually exclusive!";
    }
  ];

  settings = {
    withSIPDisabled = false;
    additionalRules = [ ];
    additionalKeyBindings = { };
    additionalConfig = { };
    additionalApplicationMapping = { };
    additionalTerminalAppsMapping = { };
    bordersSize = 15;
    barHeight = 77;
    iconFontSize = "23.0";
    labelFontSize = "18.0";
    appIconFontSize = "22.0";
    separatorFontSize = "24.0";
    defaultAppIcon = "app";
    baseTerminalAppsMapping = {
      chart = [
        "btop"
        "htop"
      ];
      dev = [
        "nvim"
        "emacs"
      ];
      file = [ "ranger" ];
      git = [ "lazygit" ];
      note = [ "bat" ];
    };
    baseApplicationMapping = {
      term = [
        "Terminal"
        "iTerm2"
        "Ghostty"
        "Kitty"
      ];
      file = [ "Finder" ];
      weather = [ "Weather" ];
      clock = [ "Clock" ];
      mail = [ "Mail" ];
      calendar = [ "Calendar" ];
      calc = [
        "Calculator"
        "Numi"
      ];
      map = [
        "Maps"
        "Find My"
      ];
      microphone = [ "Voice Memos" ];
      chat = [ "Messages" ];
      videochat = [ "FaceTime" ];
      note = [
        "Notes"
        "TextEdit"
      ];
      list = [ "Reminders" ];
      camera = [ "Photo Booth" ];
      web = [
        "Safari"
        "Google Chrome"
        "Chromium"
        "Firefox"
        "Qutebrowser"
      ];
      cog = [
        "System Settings"
        "System Information"
      ];
      music = [ "Music" ];
      podcast = [ "Podcasts" ];
      play = [ "TV" ];
      book = [ "Books" ];
      dev = [
        "Xcode"
        "Code"
      ];
      bookinfo = [
        "Font Book"
        "Dictionary"
      ];
      chart = [ "Activity Monitor" ];
      disk = [ "Disk Utility" ];
      preview = [
        "Screenshot"
        "Preview"
      ];
    };
    baseConfig = {
      "layout" = "bsp";
      "window_placement" = "first_child";
      "split_ratio" = "0.50";
      "auto_balance" = "on";

      "mouse_follows_focus" = "off";
      "focus_follows_mouse" = "off";
      "mouse_modifier" = "fn";
      "mouse_action1" = "move";
      "mouse_action2" = "resize";
      "mouse_drop_action" = "swap";

      "top_padding" = "15";
      "bottom_padding" = "15";
      "left_padding" = "15";
      "right_padding" = "15";
      "window_gap" = "5";

      "window_opacity" = "off";
      "window_shadow" = "off";
    };
    baseRules = [
      ''app="^System Settings$" manage=off''
      ''app="^System Preferences$" manage=off''
      ''app="^Archive Utility$" manage=off''
      ''app="^Finder$" title="(Copy|Connect|Move|Info|Preferences)" manage=off''
      ''app="^Calculator$" manage=off''
      ''app="^Dictionary$" manage=off''
      ''app="^Software Update$" manage=off''
      ''app="^About This Mac$" manage=off''
      ''title="^Opening" manage=off''
      ''title="^Trash" manage=off''
    ];
  };

  configuration =
    context@{ config, options, ... }:
    let
      stylixConfig =
        if self.common.isModuleEnabled "style.stylix" then
          self.common.getModuleConfig "style.stylix"
        else
          null;

      iconFontSize = self.settings.iconFontSize;
      labelFontSize = self.settings.labelFontSize;
      appIconFontSize = self.settings.appIconFontSize;
      separatorFontSize = self.settings.separatorFontSize;

      iconFont =
        if stylixConfig != null then
          let
            monoPath =
              if builtins.isString stylixConfig.fonts.monospace then
                stylixConfig.fonts.monospace
              else
                stylixConfig.fonts.monospace.path;
            monoName = lib.last (lib.splitString "/" monoPath);
          in
          "${monoName}:Bold:${iconFontSize}"
        else
          "SF Mono:Bold:${iconFontSize}";

      labelFont =
        if stylixConfig != null then
          let
            sansPath =
              if builtins.isString stylixConfig.fonts.sansSerif then
                stylixConfig.fonts.sansSerif
              else
                stylixConfig.fonts.sansSerif.path;
            sansName = lib.last (lib.splitString "/" sansPath);
          in
          "${sansName}:Bold:${labelFontSize}"
        else
          "SF Pro Display:Bold:${labelFontSize}";

      appIconFont =
        if stylixConfig != null then
          let
            monoPath =
              if builtins.isString stylixConfig.fonts.monospace then
                stylixConfig.fonts.monospace
              else
                stylixConfig.fonts.monospace.path;
            monoName = lib.last (lib.splitString "/" monoPath);
          in
          "${monoName}:Regular:${appIconFontSize}"
        else
          "SF Mono:Regular:${appIconFontSize}";

      separatorFont =
        if stylixConfig != null then
          let
            monoPath =
              if builtins.isString stylixConfig.fonts.monospace then
                stylixConfig.fonts.monospace
              else
                stylixConfig.fonts.monospace.path;
            monoName = lib.last (lib.splitString "/" monoPath);
          in
          "${monoName}:Bold:${separatorFontSize}"
        else
          "SF Mono:Bold:${separatorFontSize}";

      colors = {
        background = "0xe01d2021";
        transparentBackground = "0x00000000";
        blackBackground = "0xff000000";
        border = "0xff88cc66";
        foreground = "0xe0fbf1c7";
        accent = "0xe0d65d0e";
        accentBright = "0xe0fe8019";
        black = "0xe0282828";
        red = "0xe0cc241d";
        green = "0xe098971a";
        yellow = "0xe0d79921";
        blue = "0xe0458588";
        magenta = "0xe0b16286";
        cyan = "0xe0689d6a";
        white = "0xe0a89984";
        blackBright = "0xe0928374";
        redBright = "0xe0fb4934";
        greenBright = "0xe0b8bb26";
        yellowBright = "0xe0fabd2f";
        blueBright = "0xe083a598";
        magentaBright = "0xe0d3869b";
        cyanBright = "0xe08ec07c";
        whiteBright = "0xe0ebdbb2";
      };

      icons = {
        cmd = "󰘳";
        cog = "󰒓";
        chart = "󱕍";
        lock = "󰌾";

        spaces = [
          "󰎤"
          "󰎧"
          "󰎪"
          "󰎭"
          "󰎱"
          "󰎳"
          "󰎶"
          "󰎹"
          "󰎼"
          "󰿬"
        ];

        app = "󰣆";
        term = "󰆍";
        package = "󰏓";
        dev = "󰅨";
        file = "󰉋";
        git = "󰊢";
        list = "󱃔";
        screensaver = "󱄄";
        weather = "󰖕";
        mail = "󰇮";
        calc = "󰪚";
        map = "󰆋";
        microphone = "󰍬";
        chat = "󰍩";
        videochat = "󰍫";
        note = "󱞎";
        camera = "󰄀";
        web = "󰇧";
        homeautomation = "󱉑";
        music = "󰎄";
        podcast = "󰦔";
        play = "󱉺";
        book = "󰂿";
        bookinfo = "󱁯";
        preview = "󰋲";
        passkey = "󰷡";
        download = "󱑢";
        cast = "󱒃";
        table = "󰓫";
        present = "󰈩";
        cloud = "󰅧";
        pen = "󰏬";
        remotedesktop = "󰢹";
        clock = "󰥔";
        calendar = "󰃭";
        wifi = "󰖩";
        wifiOff = "󰖪";
        vpn = "󰦝";
        volume = "󰖀";
        battery = "󰁹";
        swap = "󰁯";
        ram = "󰓅";
        disk = "󰋊";
        cpu = "󰘚";
      };

      spaceColors = [
        colors.yellow
        colors.cyan
        colors.magenta
        colors.white
        colors.blue
        colors.red
        colors.green
        colors.yellow
        colors.cyan
        colors.magenta
      ];

      backgroundHeight = builtins.toString (builtins.div (self.settings.barHeight * 8) 10);
      paddingSpace = self.settings.barHeight - (builtins.div (self.settings.barHeight * 8) 10);
      textYOffset = builtins.toString (builtins.div paddingSpace 4);
      labelFontSizeNum = lib.toInt (lib.removeSuffix ".0" self.settings.labelFontSize);
      separatorFontSizeNum = lib.toInt (lib.removeSuffix ".0" self.settings.separatorFontSize);
      fontSizeDiff = separatorFontSizeNum - labelFontSizeNum;
      separatorYOffset = builtins.toString (
        (builtins.div paddingSpace 4) + (builtins.div fontSizeDiff 3)
      );
    in
    {
      home.packages = with pkgs; [
        jq
      ];

      home.file.".config/homebrew/yabai.tap".text = ''
        tap 'koekeishiya/formulae'
        tap 'FelixKratz/formulae'
      '';

      home.file.".config/homebrew/yabai.brew".text = ''
        brew 'yabai', args: ["HEAD"]
        brew 'skhd'
        brew 'borders', restart_service: :changed
        brew 'sketchybar', restart_service: :changed
      '';

      home.file.".config/yabai/yabairc" =
        let
          allConfig =
            self.settings.baseConfig
            // self.settings.additionalConfig
            // {
              "external_bar" = "all:${builtins.toString self.settings.barHeight}:0";
              "top_padding" = builtins.toString (
                (lib.toInt self.settings.baseConfig.top_padding) + self.settings.bordersSize
              );
              "bottom_padding" = builtins.toString (
                (lib.toInt self.settings.baseConfig.bottom_padding) + self.settings.bordersSize
              );
              "left_padding" = builtins.toString (
                (lib.toInt self.settings.baseConfig.left_padding) + self.settings.bordersSize
              );
              "right_padding" = builtins.toString (
                (lib.toInt self.settings.baseConfig.right_padding) + self.settings.bordersSize
              );
              "window_gap" = builtins.toString (
                (lib.toInt self.settings.baseConfig.window_gap) + (self.settings.bordersSize * 2)
              );
            };
          allRules = self.settings.baseRules ++ self.settings.additionalRules;
        in
        {
          executable = true;
          text = ''
            #!/usr/bin/env bash

            ${lib.optionalString self.settings.withSIPDisabled ''
              yabai -m signal --add event=dock_did_restart action="sudo yabai --load-sa"
              sudo yabai --load-sa || true
            ''}

            ${lib.concatStringsSep "\n" (
              lib.mapAttrsToList (key: value: "yabai -m config ${key} ${value}") allConfig
            )}

            ${lib.optionalString self.settings.withSIPDisabled ''
              function setup_spaces {
                local space_count=$(yabai -m query --spaces | jq '. | length')

                while [ $space_count -lt 11 ]; do
                  yabai -m space --create
                  space_count=$((space_count + 1))
                done

                for i in {1..10}; do
                  yabai -m space $i --label "s$i"
                done
                yabai -m space 11 --label "scratch"
              }
              setup_spaces
            ''}

            ${lib.concatMapStrings (rule: ''
              yabai -m rule --add ${rule}
            '') allRules}

            yabai -m signal --add event=window_created action="sketchybar -m --trigger window_change &> /dev/null"
            yabai -m signal --add event=window_destroyed action="sketchybar -m --trigger window_change &> /dev/null"

            brew services start borders || true
            brew services start sketchybar || true
          '';
        };

      home.file.".config/skhd/skhdrc" =
        let
          baseKeybinds = {
            "alt - h" = "yabai -m window --focus west";
            "alt - j" = "yabai -m window --focus south";
            "alt - k" = "yabai -m window --focus north";
            "alt - l" = "yabai -m window --focus east";

            "shift + alt - h" = "${self.user.home}/.local/bin/scripts/yabai-move-column.sh left";
            "shift + alt - j" = "yabai -m window --swap south";
            "shift + alt - k" = "yabai -m window --swap north";
            "shift + alt - l" = "${self.user.home}/.local/bin/scripts/yabai-move-column.sh right";

            "ctrl + alt - h" = "yabai -m window --resize left:-200:0 || yabai -m window --resize right:-200:0";
            "ctrl + alt - j" = "yabai -m window --resize bottom:0:200 || yabai -m window --resize top:0:200";
            "ctrl + alt - k" = "yabai -m window --resize top:0:-200 || yabai -m window --resize bottom:0:-200";
            "ctrl + alt - l" = "yabai -m window --resize right:200:0 || yabai -m window --resize left:200:0";

            "alt - f" = "yabai -m window --toggle zoom-fullscreen";
            "shift + alt - f" = "yabai -m window --toggle native-fullscreen";
            "alt - backspace" = "yabai -m window --toggle float";

            "alt - g" = "yabai -m space --balance";
            "alt - r" = "yabai -m space --rotate 270";
            "shift + alt - r" = "yabai -m space --rotate 90";

            "alt - a" = "yabai -m window --toggle split";

            "alt - return" = "open -na Ghostty";
            "shift + alt - return" = "open -na Tmux";

            "alt - p" =
              "mkdir -p ~/Pictures/screenshots && screencapture -i ~/Pictures/screenshots/$(date +%Y_%m_%d_%H%M%S).png";
            "shift + alt - p" =
              "mkdir -p ~/Pictures/screenshots && screencapture -iw ~/Pictures/screenshots/$(date +%Y_%m_%d_%H%M%S).png";
            "ctrl + alt - p" = "mkdir -p ~/Pictures/screenshots && open ~/Pictures/screenshots";

            "shift + alt - q" = "restart-yabai";
            "shift + alt - w" = "restart-skhd";
            "alt + ctrl - tab" = "open -a \"Mission Control\"";

            "ctrl + alt - b" = "pmset sleepnow";
          };

          disabledSIPKeybinds = {
            "alt - 1" = "yabai -m space --focus 1";
            "alt - 2" = "yabai -m space --focus 2";
            "alt - 3" = "yabai -m space --focus 3";
            "alt - 4" = "yabai -m space --focus 4";
            "alt - 5" = "yabai -m space --focus 5";
            "alt - 6" = "yabai -m space --focus 6";
            "alt - 7" = "yabai -m space --focus 7";
            "alt - 8" = "yabai -m space --focus 8";
            "alt - 9" = "yabai -m space --focus 9";
            "alt - 0" = "yabai -m space --focus 10";

            "shift + alt - 1" = "yabai -m window --space 1; yabai -m space --focus 1";
            "shift + alt - 2" = "yabai -m window --space 2; yabai -m space --focus 2";
            "shift + alt - 3" = "yabai -m window --space 3; yabai -m space --focus 3";
            "shift + alt - 4" = "yabai -m window --space 4; yabai -m space --focus 4";
            "shift + alt - 5" = "yabai -m window --space 5; yabai -m space --focus 5";
            "shift + alt - 6" = "yabai -m window --space 6; yabai -m space --focus 6";
            "shift + alt - 7" = "yabai -m window --space 7; yabai -m space --focus 7";
            "shift + alt - 8" = "yabai -m window --space 8; yabai -m space --focus 8";
            "shift + alt - 9" = "yabai -m window --space 9; yabai -m space --focus 9";
            "shift + alt - 0" = "yabai -m window --space 10; yabai -m space --focus 10";

            "alt - u" = "yabai -m space --focus prev";
            "alt - d" = "yabai -m space --focus next";
            "shift + alt - tab" = "yabai -m space --focus recent";

            "shift + alt - backspace" = "yabai -m window --toggle sticky";

            "shift + alt - u" = "yabai -m window --space prev; yabai -m space --focus prev";
            "shift + alt - d" = "yabai -m window --space next; yabai -m space --focus next";
          };

          allKeybinds =
            baseKeybinds
            // (lib.optionalAttrs self.settings.withSIPDisabled disabledSIPKeybinds)
            // self.settings.additionalKeyBindings;
        in
        {
          executable = true;
          text = lib.concatStringsSep "\n" (
            lib.mapAttrsToList (key: command: "${key} : ${command}") allKeybinds
          );
        };

      home.file.".config/borders/bordersrc" = {
        executable = true;
        text = ''
          #!/bin/bash

          options=(
            width=${builtins.toString self.settings.bordersSize}
            active_color=${colors.border}
            inactive_color=${colors.transparentBackground}
            hidpi=on
          )

          borders "''${options[@]}"
        '';
      };

      home.file.".local/bin/restart-yabai" = {
        executable = true;
        text = ''
          #!/bin/bash
          launchctl kickstart -k gui/$(id -u)/com.koekeishiya.yabai
        '';
      };

      home.file.".local/bin/restart-skhd" = {
        executable = true;
        text = ''
          #!/bin/bash
          launchctl kickstart -k gui/$(id -u)/com.koekeishiya.skhd
        '';
      };

      home.file.".local/bin/scripts/yabai-get-columns.sh" = {
        executable = true;
        text = ''
          #!/bin/bash
          set -euo pipefail

          if ! windows=$(yabai -m query --windows --space); then
            echo "Error: Failed to query windows" >&2
            exit 1
          fi

          if ! echo "''${windows}" | jq empty 2>/dev/null; then
            echo "Error: Invalid JSON from yabai query" >&2
            exit 1
          fi

          columns=$(echo "''${windows}" | jq -r '
            map(select(.["is-visible"] == true and .["is-minimized"] == false and .["is-floating"] == false)) |
            map({
              id: .id,
              app: .app,
              x: .frame.x,
              y: .frame.y,
              width: .frame.w,
              height: .frame.h,
              right: (.frame.x + .frame.w),
              "split-type": .["split-type"],
              "split-child": .["split-child"]
            }) |
            sort_by(.x) |
            group_by(.x | . / 100 | floor) |
            map({
              column_index: (.[0].x | . / 100 | floor),
              left_edge: (map(.x) | min),
              right_edge: (map(.right) | max),
              windows: map({id, app, x, y, width, height, "split-type": .["split-type"], "split-child": .["split-child"]}) | sort_by(.y),
              has_stacked_windows: (length > 1),
              split_types: map(.["split-type"]) | unique
            }) |
            sort_by(.left_edge)
          ')

          echo "''${columns}"
        '';
      };

      home.file.".local/bin/scripts/yabai-move-column.sh" = {
        executable = true;
        text = ''
          #!/bin/bash
          set -euo pipefail

          readonly SCRIPT_DIR="${self.user.home}/.local/bin/scripts"
          readonly LOCK_DIR="/tmp/yabai-move-column.lock"

          if ! mkdir "''${LOCK_DIR}" 2>/dev/null; then
            echo "Warning: Another instance is already running, skipping..." >&2
            exit 0
          fi

          cleanup() {
            rmdir "''${LOCK_DIR}" 2>/dev/null || true
          }
          trap cleanup EXIT INT TERM

          if [[ $# -ne 1 ]]; then
            echo "Usage: yabai-move-column.sh <left|right>" >&2
            exit 1
          fi

          readonly direction="$1"
          if [[ "''${direction}" != "left" && "''${direction}" != "right" ]]; then
            echo "Error: Invalid direction. Use 'left' or 'right'" >&2
            exit 1
          fi

          if ! current_window=$(yabai -m query --windows --window); then
            echo "Error: Failed to query current window" >&2
            exit 1
          fi

          if ! current_id=$(echo "''${current_window}" | jq -r '.id'); then
            echo "Error: Failed to extract window ID" >&2
            exit 1
          fi

          if ! columns=$(''${SCRIPT_DIR}/yabai-get-columns.sh); then
            echo "Error: Failed to get column layout" >&2
            exit 1
          fi

          if ! analysis=$(echo "''${columns}" | jq -r --arg window_id "''${current_id}" --arg direction "''${direction}" '
            . as $root |
            map(select(.windows[] | .id == ($window_id | tonumber))) as $current_columns |
            $current_columns[0] as $current_column |

            ($root | map(.left_edge)) as $all_edges |
            ($all_edges | to_entries | map(select(.value == $current_column.left_edge)) | .[0].key) as $current_index |

            (if $direction == "left" then ($current_index - 1) else ($current_index + 1) end) as $target_index |

            (if ($target_index >= 0 and $target_index < ($root | length)) then $root[$target_index] else null end) as $target_column |

            {
              current_column: $current_column,
              target_column: $target_column,
              has_target: ($target_column != null),
              action: (if ($target_column != null) then "move_into_column" else "move_out_of_column" end)
            }
          '); then
            echo "Error: Failed to analyze column layout" >&2
            exit 1
          fi

          readonly action=$(echo "''${analysis}" | jq -r '.action')
          readonly has_target=$(echo "''${analysis}" | jq -r '.has_target')

          if [[ "''${action}" == "move_into_column" ]]; then
            echo "Moving window into existing column..."

            if ! target_window_id=$(echo "''${analysis}" | jq -r '.target_column.windows[-1].id'); then
              echo "Error: Failed to get target window ID" >&2
              exit 1
            fi

            target_window_count=$(echo "''${analysis}" | jq -r '.target_column.windows | length')
            target_split_type=$(echo "''${analysis}" | jq -r '.target_column.windows[0]["split-type"]')

            if [[ ''${target_window_count} -eq 1 && "''${target_split_type}" == "vertical" ]]; then
              echo "Detected 2-window side-by-side layout, using warp+split strategy to create stack..."

              if [[ "''${direction}" == "left" ]]; then
                yabai -m window --warp west
              else
                yabai -m window --warp east
              fi

              yabai -m window --toggle split
            else
              echo "Using direct window warp for existing stack (''${target_window_count} windows)..."
              yabai -m window "''${current_id}" --warp "''${target_window_id}"
            fi
          else
            echo "Moving window out of current column..."

            if ! current_split=$(yabai -m query --windows --window | jq -r '.["split-type"]'); then
              echo "Warning: Could not get current split type, using simple warp" >&2
              if [[ "''${direction}" == "left" ]]; then
                yabai -m window --warp west
              else
                yabai -m window --warp east
              fi
            else
              echo "Current split type: ''${current_split}"

              if [[ "''${current_split}" == "none" ]]; then
                echo "Using simple warp to create new column..."
                if [[ "''${direction}" == "left" ]]; then
                  yabai -m window --warp west
                else
                  yabai -m window --warp east
                fi
              else
                echo "Using split toggle to break out of stack..."
                yabai -m window --toggle split

                if ! current_column_info=$(echo "''${columns}" | jq -r --arg window_id "''${current_id}" '
                  map(select(.windows[] | .id == ($window_id | tonumber))) | .[0]
                '); then
                  echo "Warning: Could not analyze current column complexity" >&2
                else
                  current_column_size=$(echo "''${current_column_info}" | jq -r '.windows | length')
                  echo "Current column has ''${current_column_size} windows"

                  if [[ ''${current_column_size} -ge 3 ]]; then
                    echo "Complex stack detected (''${current_column_size} windows), following with warp for clean separation..."
                    if [[ "''${direction}" == "left" ]]; then
                      yabai -m window --warp west
                    else
                      yabai -m window --warp east
                    fi
                  elif [[ ''${current_column_size} -eq 2 ]]; then
                    column_count=$(echo "''${columns}" | jq '. | length')
                    if [[ ''${column_count} -ge 2 ]]; then
                      echo "Multiple columns detected, using warp for precise positioning..."
                      if [[ "''${direction}" == "left" ]]; then
                        yabai -m window --warp west
                      else
                        yabai -m window --warp east
                      fi
                    fi
                  fi
                fi
              fi
            fi
          fi
        '';
      };

      home.file.".config/sketchybar/sketchybarrc" = {
        executable = true;
        text = ''
          #!/bin/bash

          PLUGIN_DIR="$HOME/.config/sketchybar/plugins"
          EXAMPLE_PLUGIN_DIR="$(brew --prefix)/share/sketchybar/examples/plugins"

          sketchybar --bar position=top height=${builtins.toString self.settings.barHeight} blur_radius=0 color=${colors.blackBackground} \
                               border_color=${colors.blackBackground} \
                               border_width=4

          sketchybar --default padding_left=12                                   \
                               padding_right=12                                  \
                                                                                \
                               background.border_width=0                        \
                               background.height=${backgroundHeight}            \
                               background.corner_radius=0                       \
                               background.color=${colors.transparentBackground} \
                                                                                \
                               icon.color=${colors.border}                      \
                               icon.highlight_color=${colors.border}            \
                               icon.padding_left=8                              \
                               icon.padding_right=4                             \
                               icon.font="${iconFont}"                          \
                               icon.y_offset=${textYOffset}                     \
                                                                                \
                               label.color=${colors.border}                     \
                               label.highlight_color=${colors.border}           \
                               label.padding_left=4                             \
                               label.padding_right=8                            \
                               label.font="${labelFont}"                        \
                               label.y_offset=${textYOffset}

          sketchybar --add event window_change

          ${lib.concatMapStringsSep "\n" (
            i:
            let
              idx = i - 1;
              spaceIcon = lib.elemAt icons.spaces idx;
              spaceColor = lib.elemAt spaceColors idx;
              padLeft = if i == 1 then "12" else "4";
              padRight = if i == 10 then "12" else "4";
              clickScript = lib.optionalString self.settings.withSIPDisabled ''
                \
                                                      click_script="yabai -m space --focus ${toString i}"'';
            in
            ''
              sketchybar --add space space.${toString i} left \
                         --set space.${toString i} script="$PLUGIN_DIR/app_space.sh" \
                                       associated_space=${toString i} \
                                       padding_left=${padLeft} \
                                       padding_right=${padRight} \
                                       icon=${spaceIcon} \
                                       icon.color=${spaceColor} \
                                       label="_" \
                                       label.color=${spaceColor}${clickScript} \
                         --subscribe space.${toString i} front_app_switched window_change
            ''
          ) (lib.range 1 10)}

          sketchybar --add item arrow left \
                     --set arrow label="⇒" \
                                 icon.drawing=off \
                                 label.color=${colors.border} \
                                 label.font="${separatorFont}" \
                                 label.y_offset=${separatorYOffset} \
                                 padding_left=4 \
                                 padding_right=4 \
                                 background.color=${colors.transparentBackground}

          sketchybar --add item front_app left \
                     --set front_app icon.color=${colors.border} \
                                     icon.font="${appIconFont}" \
                                     icon.padding_left=12 \
                                     icon.padding_right=3 \
                                     label.font="${labelFont}" \
                                     label.color=${colors.border} \
                                     label.padding_left=6 \
                                     label.padding_right=16 \
                                     background.color=${colors.transparentBackground} \
                                     script="$PLUGIN_DIR/front_app.sh" \
                     --subscribe front_app front_app_switched window_change

          sketchybar --add item clock right \
                     --set clock icon=${icons.clock} \
                                icon.color=${colors.border} \
                                icon.font="${iconFont}" \
                                label.font="${labelFont}" \
                                background.color=${colors.transparentBackground} \
                                padding_left=12 \
                                padding_right=12 \
                                update_freq=10 \
                                script="$PLUGIN_DIR/clock_custom.sh"

          sketchybar --add item volume right \
                     --set volume icon=${icons.volume} \
                                 icon.color=${colors.border} \
                                 icon.font="${iconFont}" \
                                 label.font="${labelFont}" \
                                 background.color=${colors.transparentBackground} \
                                 padding_left=8 \
                                 padding_right=8 \
                                 script="$EXAMPLE_PLUGIN_DIR/volume.sh" \
                     --subscribe volume volume_change

          sketchybar --add item battery right \
                     --set battery icon.color=${colors.border} \
                                  icon.font="${iconFont}" \
                                  label.font="${labelFont}" \
                                  background.color=${colors.transparentBackground} \
                                  padding_left=8 \
                                  padding_right=8 \
                                  update_freq=120 \
                                  script="$EXAMPLE_PLUGIN_DIR/battery.sh" \
                     --subscribe battery system_woke power_source_change

          sketchybar --update
        '';
      };

      home.file.".config/sketchybar/plugins/clock_custom.sh" = {
        executable = true;
        text = ''
          #!/bin/bash

          sketchybar --set "$NAME" label="$(date "+%d/%m/%y %H:%M")"
        '';
      };

      home.file.".config/sketchybar/plugins/front_app.sh" = {
        executable = true;
        text = ''
          #!/bin/bash

          if [[ $SENDER == "front_app_switched" ]]; then
            FOCUSED_WINDOW=$(yabai -m query --windows --window 2>/dev/null)

            if [[ "$FOCUSED_WINDOW" == "null" ]] || [[ -z "$FOCUSED_WINDOW" ]]; then
              sketchybar --set front_app drawing=off
            else
              IS_STICKY=$(echo "$FOCUSED_WINDOW" | jq -r '.["is-sticky"] // false')

              if [[ "$IS_STICKY" == "true" ]]; then
                sketchybar --set front_app drawing=off
              else
                sketchybar --set front_app drawing=on

                APP_NAME="$INFO"
                WINDOW_TITLE=$(echo "$FOCUSED_WINDOW" | jq -r '.title // ""')

                ICON=$($HOME/.config/sketchybar/plugins/app_icon.sh "$APP_NAME" "$WINDOW_TITLE")

                sketchybar --set front_app icon="$ICON" label="$APP_NAME"
              fi
            fi
          elif [[ $SENDER == "window_change" ]]; then
            FOCUSED_WINDOW=$(yabai -m query --windows --window 2>/dev/null)

            if [[ "$FOCUSED_WINDOW" == "null" ]] || [[ -z "$FOCUSED_WINDOW" ]]; then
              sketchybar --set front_app drawing=off
            else
              IS_STICKY=$(echo "$FOCUSED_WINDOW" | jq -r '.["is-sticky"] // false')

              if [[ "$IS_STICKY" == "true" ]]; then
                sketchybar --set front_app drawing=off
              else
                sketchybar --set front_app drawing=on
              fi
            fi
          fi
        '';
      };

      home.file.".config/sketchybar/plugins/app_space.sh" =
        let
          spaceHighlightColors = lib.listToAttrs (
            lib.imap0 (idx: color: {
              name = toString (idx + 1);
              value = "0x44" + lib.removePrefix "0xe0" (lib.removePrefix "0xff" color);
            }) spaceColors
          );
        in
        {
          executable = true;
          text = ''
            #!/bin/bash

            SPACE_NUM=''${NAME#space.}

            declare -A SPACE_COLORS=(
              ${lib.concatStringsSep "\n            " (
                lib.mapAttrsToList (num: color: "[${num}]=\"${color}\"") spaceHighlightColors
              )}
            )

            if [[ $SELECTED == "true" ]]; then
              HIGHLIGHT_COLOR="''${SPACE_COLORS[$SPACE_NUM]}"
              sketchybar --set $NAME background.drawing=on \
                                    background.color="$HIGHLIGHT_COLOR" \
                                    background.corner_radius=0
            else
              sketchybar --set $NAME background.drawing=off
            fi

            if [[ $SENDER == "front_app_switched" || $SENDER == "window_change" ]]; then
             for i in {1..10}; do
               sid=$i
               LABEL=""

               QUERY=$(yabai -m query --windows --space $sid)
               FILTERED_QUERY=$(echo $QUERY | jq '[.[] | select(.["is-sticky"] == false)]')
               APPS=$(echo $FILTERED_QUERY | jq '.[].app')
               TITLES=$(echo $FILTERED_QUERY | jq '.[].title')

               if grep -q "\"" <<< $APPS; then
                 APPS_ARR=()
                 while read -r line; do APPS_ARR+=("$line"); done <<< "$APPS"
                 TITLES_ARR=()
                 while read -r line; do TITLES_ARR+=("$line"); done <<< "$TITLES"

                 LENGTH=''${#APPS_ARR[@]}
                 for j in "''${!APPS_ARR[@]}"; do
                   APP=$(echo ''${APPS_ARR[j]} | sed 's/"//g')
                   TITLE=$(echo ''${TITLES_ARR[j]} | sed 's/"//g')

                   ICON=$($HOME/.config/sketchybar/plugins/app_icon.sh "$APP" "$TITLE")
                   LABEL+="$ICON"
                   if [[ $j < $(($LENGTH-1)) ]]; then
                     LABEL+="  "
                   fi
                 done
               else
                 LABEL=""
               fi

               sketchybar --set space.$sid label="$LABEL"
             done
            fi
          '';
        };

      home.file.".config/sketchybar/plugins/app_icon.sh" =
        let
          mergeAppMappings =
            base: additional:
            let
              allKeys = lib.unique ((lib.attrNames base) ++ (lib.attrNames additional));
            in
            lib.genAttrs allKeys (key: (base.${key} or [ ]) ++ (additional.${key} or [ ]));

          allApplicationMapping = mergeAppMappings self.settings.baseApplicationMapping self.settings.additionalApplicationMapping;
          allTerminalAppsMapping = mergeAppMappings self.settings.baseTerminalAppsMapping self.settings.additionalTerminalAppsMapping;

          buildCaseStatements = lib.concatStringsSep "\n" (
            lib.mapAttrsToList (
              iconName: apps:
              if iconName != "term" then
                let
                  appPattern = lib.concatStringsSep " | " (map (app: ''"${app}"'') apps);
                in
                ''
                  ${appPattern})
                      RESULT=${icons.${iconName}}
                      ;;''
              else
                ""
            ) allApplicationMapping
          );

          buildTerminalChecks = lib.concatStringsSep "\n" (
            lib.mapAttrsToList (
              iconName: patterns:
              let
                patternCheck = lib.concatStringsSep "\\|" patterns;
              in
              ''
                elif grep -q "${patternCheck}" <<< $2; then
                  RESULT=${icons.${iconName}}''
            ) allTerminalAppsMapping
          );

          terminalApps = allApplicationMapping.term or [ ];
          terminalPattern = lib.concatStringsSep " | " (map (app: ''"${app}"'') terminalApps);
        in
        {
          executable = true;
          text = ''
            #!/bin/bash

            case "$1" in
            ${terminalPattern})
              RESULT=${icons.term}
              if false; then
                :
              ${buildTerminalChecks}
              fi
              ;;
            ${buildCaseStatements}
            *)
              RESULT=${icons.${self.settings.defaultAppIcon}}
              ;;
            esac

            echo $RESULT
          '';
        };

      home.file.".config/homebrew/yabai.note".text = ''
        # Required macOS Settings:

          1. System Settings → Desktop & Dock → Mission Control → Enable "Displays have separate Spaces"
          2. System Settings → Desktop & Dock → Mission Control → Disable "Automatically rearrange Spaces"
          3. System Settings → Menu Bar → Set "Automatically hide and show the menu bar" to "Always"
          4. System Settings → Privacy & Security → Accessibility → Allow yabai and skhd binaries on first start

        ## First-time setup:

          1. Run: yabai --start-service
          2. Run: skhd --start-service
          3. Run: brew services start borders
          4. Run: brew services start sketchybar
        ${lib.optionalString self.settings.withSIPDisabled ''

          ## To disable SIP:

          1. Find out yabai shasum, Run: shasum -a 256 /opt/homebrew/bin/yabai | awk '{print $1}'
          2. Edit sudoers file, Run: sudo visudo -f /private/etc/sudoers.d/yabai
            - Add this line with <SHA> replaced:

              ${self.user.username} ALL=(root) NOPASSWD: sha256:<SHA> /opt/homebrew/bin/yabai --load-sa

          3. Boot to Recovery Mode (hold power button during boot)
          4. Menu -> Utilities -> Terminal
          5. Run (Apple Silicon macOS 13.x.x OR newer): csrutil enable --without fs --without debug --without nvram
          6. Reboot in normal mode
          7. Run: sudo nvram boot-args=-arm64e_preview_abi
          8. Reboot again
          9. Verify SIP is disabled, Run: csrutil status
        ''}
      '';
    };
}
