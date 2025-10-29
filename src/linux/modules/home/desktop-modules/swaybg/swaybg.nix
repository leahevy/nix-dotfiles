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
  name = "swaybg";

  group = "desktop-modules";
  input = "linux";
  namespace = "home";

  settings = {
    output = "*";
    mode = "fit";
    backgroundColor = "#000000";
    timerIntervalSeconds = 600;
    deactivateTimer = false;
    additionalWallpaperDirectories = [ ];
  };

  configuration =
    context@{ config, options, ... }:
    let
      getStylixWallpaper =
        let
          stylixConfig =
            if self.user.isStandalone then
              self.common.getModuleConfig "style.stylix"
            else
              self.common.host.getModuleConfig "style.stylix";

          getStylixFile =
            fileName:
            if self.user.isStandalone then
              helpers.getInputFilePath (helpers.resolveInputFromInput "common") "modules/home/style/stylix/files/${fileName}"
            else
              helpers.getInputFilePath (helpers.resolveInputFromInput "common") "modules/system/style/stylix/files/${fileName}";
        in
        if (stylixConfig.wallpaper.config or null) != null then
          self.config.filesPath stylixConfig.wallpaper.config
        else if
          (stylixConfig.wallpaper.url or null) != null && (stylixConfig.wallpaper.url.url or null) != null
        then
          pkgs.fetchurl {
            url = stylixConfig.wallpaper.url.url;
            hash = stylixConfig.wallpaper.url.hash;
          }
        else if (stylixConfig.wallpaper.local or null) != null then
          stylixConfig.wallpaper.local
        else
          getStylixFile "wallpaper.jpg";

      stylixWallpaperPath = toString getStylixWallpaper;
      stylixExtension = lib.last (lib.splitString "." stylixWallpaperPath);

      wallpapersDir = "${config.home.homeDirectory}/.config/swaybg/wallpapers";

      expandedAdditionalDirs = map (
        dir:
        if lib.hasPrefix "~" dir then "${config.home.homeDirectory}${lib.removePrefix "~" dir}" else dir
      ) self.settings.additionalWallpaperDirectories;
    in
    {
      home.packages = [ pkgs.swaybg ];

      home.file.".config/swaybg/wallpapers/stylix.${stylixExtension}" = {
        source = getStylixWallpaper;
      };

      home.file.".local/bin/swaybg-next-wallpaper" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash

          LAST_CHANGE_FILE="${self.user.home}/.local/state/swaybg-last-change"
          CURRENT_TIME=$(${pkgs.coreutils}/bin/date +%s)
          RATE_LIMIT=1

          ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$LAST_CHANGE_FILE")"

          if [[ ! -f "$LAST_CHANGE_FILE" ]] || [[ $((CURRENT_TIME - $(${pkgs.coreutils}/bin/cat "$LAST_CHANGE_FILE" 2>/dev/null || echo 0))) -gt $RATE_LIMIT ]]; then
            echo "$CURRENT_TIME" > "$LAST_CHANGE_FILE"

            ${lib.optionalString (!self.settings.deactivateTimer) ''
              systemctl --user restart nx-swaybg-rotate.timer
              systemctl --user start nx-swaybg-rotate.service
            ''}

            ${lib.optionalString (self.settings.deactivateTimer) ''
              systemctl --user restart nx-swaybg.service
            ''}
          fi
        '';
      };

      home.file.".local/bin/scripts/swaybg-start" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash
          WALLPAPERS_DIR="${wallpapersDir}"
          STATE_FILE="${config.home.homeDirectory}/.local/state/swaybg-wallpaper"

          WALLPAPERS=($(${pkgs.findutils}/bin/find "$WALLPAPERS_DIR" \( -type f -o -type l \) \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.bmp" \) 2>/dev/null))

          ${lib.concatMapStringsSep "\n" (dir: ''
            if [ -d "${dir}" ]; then
              while IFS= read -r -d "" wallpaper; do
                WALLPAPERS+=("$wallpaper")
              done < <(${pkgs.findutils}/bin/find "${dir}" \( -type f -o -type l \) \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.bmp" \) -print0 2>/dev/null)
            fi
          '') expandedAdditionalDirs}

          if [ ''${#WALLPAPERS[@]} -eq 0 ]; then
            echo "No wallpapers found, exiting gracefully"
            exit 0
          fi

          CURRENT_WALLPAPER=""
          if [ -f "$STATE_FILE" ]; then
            CURRENT_WALLPAPER=$(cat "$STATE_FILE")
          fi

          if [ ''${#WALLPAPERS[@]} -eq 1 ]; then
            WALLPAPER="''${WALLPAPERS[0]}"
          else
            for i in {1..10}; do
              WALLPAPER=$(printf '%s\n' "''${WALLPAPERS[@]}" | ${pkgs.coreutils}/bin/shuf -n 1)
              if [ "$WALLPAPER" != "$CURRENT_WALLPAPER" ]; then
                break
              fi
            done
          fi

          echo "Using wallpaper: $WALLPAPER"
          echo "Output: ${self.settings.output}"
          echo "Mode: ${self.settings.mode}"
          echo "Background color: ${self.settings.backgroundColor}"
          echo "Full command: ${pkgs.swaybg}/bin/swaybg -o ${self.settings.output} -i \"$WALLPAPER\" -m ${self.settings.mode} -c \"${self.settings.backgroundColor}\""

          mkdir -p "$(dirname "$STATE_FILE")"
          echo "$WALLPAPER" > "$STATE_FILE"

          exec ${pkgs.swaybg}/bin/swaybg -o "${self.settings.output}" -i "$WALLPAPER" -m "${self.settings.mode}" -c "${lib.removePrefix "#" self.settings.backgroundColor}"
        '';
      };

      systemd.user.services.nx-swaybg = {
        Unit = {
          Description = "Wayland wallpaper daemon";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };

        Service = {
          ExecStart = "${config.home.homeDirectory}/.local/bin/scripts/swaybg-start";
          Restart = "no";
          Type = "simple";
        };

        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
      };

      systemd.user.timers.nx-swaybg-rotate = lib.mkIf (!self.settings.deactivateTimer) {
        Unit = {
          Description = "Timer to rotate wallpapers";
        };

        Timer = {
          OnActiveSec = "${toString self.settings.timerIntervalSeconds}s";
          OnUnitActiveSec = "${toString self.settings.timerIntervalSeconds}s";
          Persistent = true;
        };

        Install = {
          WantedBy = [ "timers.target" ];
        };
      };

      systemd.user.services.nx-swaybg-rotate = lib.mkIf (!self.settings.deactivateTimer) {
        Unit = {
          Description = "Rotate wallpaper by restarting swaybg";
        };

        Service = {
          Type = "oneshot";
          ExecStart = "${pkgs.systemd}/bin/systemctl --user restart nx-swaybg.service";
        };
      };

      programs.niri.settings = lib.mkIf (self.isModuleEnabled "desktop.niri") {
        binds = with config.lib.niri.actions; {
          "Mod+Shift+backslash" = {
            action = spawn "swaybg-next-wallpaper";
            hotkey-overlay.title = "UI:Next wallpaper";
          };
        };
      };

      home.persistence."${self.persist}" = {
        directories = [
          ".config/swaybg/wallpapers"
        ];
      };
    };
}
