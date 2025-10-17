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

  defaults = {
    withSIPDisabled = false;
    additionalRules = [ ];
    additionalKeyBindings = { };
    additionalConfig = { };
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
      "window_gap" = "25";

      "window_opacity" = "off";
      "window_shadow" = "off";
      "external_bar" = "all:52:0";
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

      iconFontSize = "21.0";
      labelFontSize = "17.0";
      appIconFontSize = "21.0";
      chevronFontSize = "25.0";

      borderColor = "0xff88cc66";
      appBackgroundColor = "0xff4d6b4d";

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

      chevronFont =
        if stylixConfig != null then
          let
            monoPath =
              if builtins.isString stylixConfig.fonts.monospace then
                stylixConfig.fonts.monospace
              else
                stylixConfig.fonts.monospace.path;
            monoName = lib.last (lib.splitString "/" monoPath);
          in
          "${monoName}:Bold:${chevronFontSize}"
        else
          "SF Mono:Bold:${chevronFontSize}";
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
          allConfig = self.settings.baseConfig // self.settings.additionalConfig;
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
            width=15.0
            active_color=0xff88cc66
            inactive_color=0x00000000
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

          PLUGIN_DIR="$(brew --prefix)/share/sketchybar/examples/plugins"

          sketchybar --bar position=top height=40 blur_radius=30 color=0x40000000

          sketchybar --default icon.font="${iconFont}" \
                              icon.color=0xffffffff \
                              icon.padding_left=4 \
                              icon.padding_right=4 \
                              label.font="${labelFont}" \
                              label.color=0xffffffff \
                              label.padding_left=4 \
                              label.padding_right=4 \
                              padding_left=5 \
                              padding_right=5

          for i in {1..10}
          do
            sketchybar --add space space.$i left \
                       --set space.$i space=$i \
                                      icon=$i \
                                      icon.font="${iconFont}" \
                                      icon.padding_left=15 \
                                      icon.padding_right=8 \
                                      padding_left=0 \
                                      padding_right=0 \
                                      background.color=${appBackgroundColor} \
                                      background.corner_radius=5 \
                                      background.height=28 \
                                      background.drawing=off \
                                      script="$PLUGIN_DIR/space.sh"${lib.optionalString self.settings.withSIPDisabled ''
                                        \
                                                                             click_script="yabai -m space --focus $i"''}
          done

          sketchybar --add item chevron left \
                     --set chevron icon="→" \
                                   icon.font="${chevronFont}" \
                                   label.drawing=off \
                                   icon.color=${borderColor}

          sketchybar --add item front_app left \
                     --set front_app icon.color=${borderColor} \
                                     icon.font="${appIconFont}" \
                                     icon.padding_left=8 \
                                     icon.padding_right=4 \
                                     label.font="${labelFont}" \
                                     label.color=0xffffffff \
                                     label.padding_left=4 \
                                     label.padding_right=12 \
                                     background.color=${appBackgroundColor} \
                                     background.corner_radius=6 \
                                     background.height=24 \
                                     script="$PLUGIN_DIR/front_app.sh" \
                     --subscribe front_app front_app_switched

          sketchybar --add item clock right \
                     --set clock icon= \
                                icon.color=0xff9dd274 \
                                icon.font="${iconFont}" \
                                label.font="${labelFont}" \
                                update_freq=10 \
                                script="$CONFIG_DIR/plugins/clock_custom.sh"

          sketchybar --add item volume right \
                     --set volume icon= \
                                 icon.color=0xff9dd274 \
                                 icon.font="${iconFont}" \
                                 label.font="${labelFont}" \
                                 script="$PLUGIN_DIR/volume.sh" \
                     --subscribe volume volume_change

          sketchybar --add item battery right \
                     --set battery icon.color=0xff9dd274 \
                                  icon.font="${iconFont}" \
                                  label.font="${labelFont}" \
                                  update_freq=120 \
                                  script="$PLUGIN_DIR/battery.sh" \
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
