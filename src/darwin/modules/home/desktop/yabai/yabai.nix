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
  };

  configuration =
    context@{ config, options, ... }:
    {
      home.file.".config/homebrew/yabai.tap".text = ''
        tap 'koekeishiya/formulae'
        tap 'FelixKratz/formulae'
      '';

      home.file.".config/homebrew/yabai.brew".text = ''
        brew 'yabai', args: ["HEAD"]
        brew 'skhd'
        brew 'borders', restart_service: :changed
      '';

      home.file.".config/yabai/yabairc" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash

          ${lib.optionalString self.settings.withSIPDisabled ''
            yabai -m signal --add event=dock_did_restart action="sudo yabai --load-sa"
            sudo yabai --load-sa || true
          ''}

          yabai -m config layout                       bsp
          yabai -m config window_placement             first_child
          yabai -m config split_ratio                  0.50
          yabai -m config auto_balance                 on

          yabai -m config mouse_follows_focus          off
          yabai -m config focus_follows_mouse          off
          yabai -m config mouse_modifier               fn
          yabai -m config mouse_action1                move
          yabai -m config mouse_action2                resize
          yabai -m config mouse_drop_action            swap

          yabai -m config top_padding                  15
          yabai -m config bottom_padding               15
          yabai -m config left_padding                 15
          yabai -m config right_padding                15
          yabai -m config window_gap                   25

          yabai -m config window_opacity               off
          yabai -m config window_shadow                off

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

          yabai -m rule --add app="^System Settings$" manage=off
          yabai -m rule --add app="^System Preferences$" manage=off
          yabai -m rule --add app="^Archive Utility$" manage=off
          yabai -m rule --add app="^Finder$" title="(Copy|Connect|Move|Info|Preferences)" manage=off
          yabai -m rule --add app="^Calculator$" manage=off
          yabai -m rule --add app="^Dictionary$" manage=off
          yabai -m rule --add app="^Software Update$" manage=off
          yabai -m rule --add app="^About This Mac$" manage=off
          yabai -m rule --add title="^Opening" manage=off
          yabai -m rule --add title="^Trash" manage=off
          ${lib.concatMapStrings (rule: ''
            yabai -m rule --add ${rule}
          '') self.settings.additionalRules}

          brew services start borders || true
        '';
      };

      home.file.".config/borders/bordersrc" = {
        executable = true;
        text = ''
          #!/bin/bash

          options=(
            width=15.0
            active_color=0xff22ff22
            inactive_color=0xbb000000
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

      home.file.".config/homebrew/yabai.note".text = ''
        # Required macOS Settings:

          1. System Settings → Desktop & Dock → Mission Control → Enable "Displays have separate Spaces"
          2. System Settings → Desktop & Dock → Mission Control → Disable "Automatically rearrange Spaces"
          3. System Settings → Privacy & Security → Accessibility → Allow yabai and skhd binaries on first start

        ## First-time setup:

          1. Run: yabai --start-service
          2. Run: skhd --start-service
          3. Run: brew services start borders
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

      home.file.".config/skhd/skhdrc" = {
        executable = true;
        text = ''
          alt - h : yabai -m window --focus west
          alt - j : yabai -m window --focus south
          alt - k : yabai -m window --focus north
          alt - l : yabai -m window --focus east

          shift + alt - h : yabai -m window --swap west
          shift + alt - j : yabai -m window --swap south
          shift + alt - k : yabai -m window --swap north
          shift + alt - l : yabai -m window --swap east

          ctrl + alt - h : yabai -m window --resize left:-200:0 || yabai -m window --resize right:-200:0
          ctrl + alt - j : yabai -m window --resize bottom:0:200 || yabai -m window --resize top:0:200
          ctrl + alt - k : yabai -m window --resize top:0:-200 || yabai -m window --resize bottom:0:-200
          ctrl + alt - l : yabai -m window --resize right:200:0 || yabai -m window --resize left:200:0

          alt - f : yabai -m window --toggle zoom-fullscreen
          shift + alt - f : yabai -m window --toggle native-fullscreen
          alt - s : yabai -m window --toggle split
          alt - g : yabai -m space --balance
          alt - r : yabai -m space --rotate 270
          shift + alt - r : yabai -m space --rotate 90
          alt - backspace : yabai -m window --toggle float

          alt - return : open -na Ghostty
          shift + alt - return : open -na Tmux

          alt - p : screencapture -i ~/Pictures/screenshots/$(date +%Y_%m_%d_%H%M%S).png
          shift + alt - p : screencapture -iw ~/Pictures/screenshots/$(date +%Y_%m_%d_%H%M%S).png

          shift + alt - q : restart-yabai
          shift + alt - w : restart-skhd
          alt + ctrl - tab : open -a "Mission Control"

          ctrl + alt - b : pmset sleepnow

          ${lib.concatStringsSep "\n" (
            lib.mapAttrsToList (key: command: "${key} : ${command}") self.settings.additionalKeyBindings
          )}

          ${lib.optionalString self.settings.withSIPDisabled ''
            alt - 1 : yabai -m space --focus 1
            alt - 2 : yabai -m space --focus 2
            alt - 3 : yabai -m space --focus 3
            alt - 4 : yabai -m space --focus 4
            alt - 5 : yabai -m space --focus 5
            alt - 6 : yabai -m space --focus 6
            alt - 7 : yabai -m space --focus 7
            alt - 8 : yabai -m space --focus 8
            alt - 9 : yabai -m space --focus 9
            alt - 0 : yabai -m space --focus 10

            shift + alt - 1 : yabai -m window --space 1; yabai -m space --focus 1
            shift + alt - 2 : yabai -m window --space 2; yabai -m space --focus 2
            shift + alt - 3 : yabai -m window --space 3; yabai -m space --focus 3
            shift + alt - 4 : yabai -m window --space 4; yabai -m space --focus 4
            shift + alt - 5 : yabai -m window --space 5; yabai -m space --focus 5
            shift + alt - 6 : yabai -m window --space 6; yabai -m space --focus 6
            shift + alt - 7 : yabai -m window --space 7; yabai -m space --focus 7
            shift + alt - 8 : yabai -m window --space 8; yabai -m space --focus 8
            shift + alt - 9 : yabai -m window --space 9; yabai -m space --focus 9
            shift + alt - 0 : yabai -m window --space 10; yabai -m space --focus 10

            alt - u : yabai -m space --focus prev
            alt - d : yabai -m space --focus next
            shift + alt - tab : yabai -m space --focus recent

            shift + alt - backspace : yabai -m window --toggle sticky

            shift + alt - u : yabai -m window --space prev; yabai -m space --focus prev
            shift + alt - d : yabai -m window --space next; yabai -m space --focus next
          ''}
        '';
      };
    };
}
