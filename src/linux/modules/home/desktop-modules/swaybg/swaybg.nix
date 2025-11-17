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
    deactivateTimer = true;
    additionalWallpaperDirectories = [ ];
    useSwitcher = true;
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

          LAST_CHANGE_FILE="${self.user.home}/.local/state/swaybg/last-change"
          CURRENT_TIME=$(${pkgs.coreutils}/bin/date +%s)
          RATE_LIMIT=1

          ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$LAST_CHANGE_FILE")"

          if [[ ! -f "$LAST_CHANGE_FILE" ]] || [[ $((CURRENT_TIME - $(${pkgs.coreutils}/bin/cat "$LAST_CHANGE_FILE" 2>/dev/null || echo 0))) -gt $RATE_LIMIT ]]; then
            echo "$CURRENT_TIME" > "$LAST_CHANGE_FILE"

            ${config.home.homeDirectory}/.local/bin/scripts/swaybg-update-wallpaper --randomize

            ${lib.optionalString (!self.settings.deactivateTimer) ''
              systemctl --user restart nx-swaybg-rotate.timer
            ''}

            systemctl --user restart nx-swaybg.service
          fi
        '';
      };

      home.file.".local/bin/swaybg-enable-wallpaper" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash

          if [[ $# -ne 1 ]]; then
            echo "Usage: swaybg-enable-wallpaper <wallpaper-filename>"
            exit 1
          fi

          WALLPAPER_NAME="$(basename "$1")"
          WALLPAPERS_DIR="${wallpapersDir}"
          WALLPAPER_PATH=""

          if [[ -f "$WALLPAPERS_DIR/$WALLPAPER_NAME" ]]; then
            WALLPAPER_PATH="$WALLPAPERS_DIR/$WALLPAPER_NAME"
          else
            ${lib.concatMapStringsSep "\n" (dir: ''
              if [[ -z "$WALLPAPER_PATH" && -d "${dir}" && -f "${dir}/$WALLPAPER_NAME" ]]; then
                WALLPAPER_PATH="${dir}/$WALLPAPER_NAME"
              fi
            '') expandedAdditionalDirs}
          fi

          if [[ -z "$WALLPAPER_PATH" ]]; then
            echo "Wallpaper '$WALLPAPER_NAME' not found in any configured directory"
            exit 1
          fi

          LAST_CHANGE_FILE="${self.user.home}/.local/state/swaybg/last-change"
          CURRENT_TIME=$(${pkgs.coreutils}/bin/date +%s)
          RATE_LIMIT=1

          ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$LAST_CHANGE_FILE")"

          if [[ ! -f "$LAST_CHANGE_FILE" ]] || [[ $((CURRENT_TIME - $(${pkgs.coreutils}/bin/cat "$LAST_CHANGE_FILE" 2>/dev/null || echo 0))) -gt $RATE_LIMIT ]]; then
            echo "$CURRENT_TIME" > "$LAST_CHANGE_FILE"

            STATE_FILE="${config.home.homeDirectory}/.local/state/swaybg/current-wallpaper"
            ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$STATE_FILE")"
            echo "$WALLPAPER_PATH" > "$STATE_FILE"

            echo "Enabled wallpaper: $WALLPAPER_PATH"

            ${lib.optionalString (!self.settings.deactivateTimer) ''
              systemctl --user restart nx-swaybg-rotate.timer
            ''}

            systemctl --user restart nx-swaybg.service
          else
            echo "Rate limited: please wait before switching wallpapers again" ?>&2
            exit 1
          fi
        '';
      };

      home.file.".local/bin/swaybg-add-wallpaper" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash

          if [[ $# -ne 1 ]]; then
            echo "Usage: swaybg-add-wallpaper <wallpaper-file-path>"
            exit 1
          fi

          SOURCE_FILE="$1"

          if [[ ! -f "$SOURCE_FILE" ]]; then
            echo "Error: Source file '$SOURCE_FILE' does not exist" >&2
            exit 1
          fi

          if ! ${pkgs.file}/bin/file "$SOURCE_FILE" | ${pkgs.gnugrep}/bin/grep -qE '\.(jpg|jpeg|png)$|image'; then
            echo "Error: '$SOURCE_FILE' does not appear to be a supported image file" >&2
            exit 1
          fi

          WALLPAPERS_DIR="${wallpapersDir}"
          SOURCE_MD5=$(${pkgs.coreutils}/bin/md5sum "$SOURCE_FILE" | ${pkgs.coreutils}/bin/cut -d' ' -f1)
          SOURCE_BASENAME=$(${pkgs.coreutils}/bin/basename "$SOURCE_FILE")

          echo "Checking for duplicate wallpapers (MD5: $SOURCE_MD5)..."

          DUPLICATE_FOUND=""
          if [[ -d "$WALLPAPERS_DIR" ]]; then
            for wallpaper in "$WALLPAPERS_DIR"/*; do
              if [[ -f "$wallpaper" ]]; then
                WALLPAPER_MD5=$(${pkgs.coreutils}/bin/md5sum "$wallpaper" | ${pkgs.coreutils}/bin/cut -d' ' -f1)
                if [[ "$SOURCE_MD5" == "$WALLPAPER_MD5" ]]; then
                  DUPLICATE_FOUND="$wallpaper"
                  break
                fi
              fi
            done
          fi

          if [[ -z "$DUPLICATE_FOUND" ]]; then
            ${lib.concatMapStringsSep "\n" (dir: ''
              if [[ -z "$DUPLICATE_FOUND" && -d "${dir}" ]]; then
                for wallpaper in "${dir}"/*; do
                  if [[ -f "$wallpaper" ]]; then
                    WALLPAPER_MD5=$(${pkgs.coreutils}/bin/md5sum "$wallpaper" | ${pkgs.coreutils}/bin/cut -d' ' -f1)
                    if [[ "$SOURCE_MD5" == "$WALLPAPER_MD5" ]]; then
                      DUPLICATE_FOUND="$wallpaper"
                      break
                    fi
                  fi
                done
              fi
            '') expandedAdditionalDirs}
          fi

          if [[ -n "$DUPLICATE_FOUND" ]]; then
            echo "Duplicate wallpaper found: $(${pkgs.coreutils}/bin/basename "$DUPLICATE_FOUND")"
            echo "Enabling existing wallpaper instead of copying..."
            exec "${config.home.homeDirectory}/.local/bin/swaybg-enable-wallpaper" "$(${pkgs.coreutils}/bin/basename "$DUPLICATE_FOUND")"
          fi

          NAME_EXISTS=""
          if [[ -f "$WALLPAPERS_DIR/$SOURCE_BASENAME" ]]; then
            NAME_EXISTS="$WALLPAPERS_DIR/$SOURCE_BASENAME"
          else
            ${lib.concatMapStringsSep "\n" (dir: ''
              if [[ -z "$NAME_EXISTS" && -d "${dir}" && -f "${dir}/$SOURCE_BASENAME" ]]; then
                NAME_EXISTS="${dir}/$SOURCE_BASENAME"
              fi
            '') expandedAdditionalDirs}
          fi

          if [[ -n "$NAME_EXISTS" ]]; then
            echo "Error: A wallpaper with the name '$SOURCE_BASENAME' already exists at: $NAME_EXISTS" >&2
            echo "Please rename the file or remove the existing wallpaper first" >&2
            exit 1
          fi

          ${pkgs.coreutils}/bin/mkdir -p "$WALLPAPERS_DIR"

          DEST_FILE="$WALLPAPERS_DIR/$SOURCE_BASENAME"

          echo "Copying '$SOURCE_FILE' to '$SOURCE_BASENAME'..."
          ${pkgs.coreutils}/bin/cp "$SOURCE_FILE" "$DEST_FILE"

          if [[ $? -eq 0 ]]; then
            echo "Successfully added wallpaper: $SOURCE_BASENAME"
            echo "Enabling new wallpaper..."
            exec "${config.home.homeDirectory}/.local/bin/swaybg-enable-wallpaper" "$SOURCE_BASENAME"
          else
            echo "Error: Failed to copy wallpaper file" >&2
            exit 1
          fi
        '';
      };

      home.file.".local/bin/swaybg-switch-wallpaper" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash

          WALLPAPERS_DIR="${wallpapersDir}"
          STATE_FILE="${config.home.homeDirectory}/.local/state/swaybg/current-wallpaper"
          CURRENT_WALLPAPER=""

          if [[ -f "$STATE_FILE" ]]; then
            CURRENT_WALLPAPER="$(${pkgs.coreutils}/bin/basename "$(${pkgs.coreutils}/bin/cat "$STATE_FILE" 2>/dev/null || echo "")")"
          fi

          WALLPAPERS=()

          if [[ -d "$WALLPAPERS_DIR" ]]; then
            while IFS= read -r -d "" wallpaper; do
              WALLPAPERS+=("$wallpaper")
            done < <(${pkgs.findutils}/bin/find "$WALLPAPERS_DIR" -maxdepth 1 \( -type f -o -type l \) \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.bmp" \) -print0 2>/dev/null)
          fi

          ${lib.concatMapStringsSep "\n" (dir: ''
            if [[ -d "${dir}" ]]; then
              while IFS= read -r -d "" wallpaper; do
                WALLPAPERS+=("$wallpaper")
              done < <(${pkgs.findutils}/bin/find "${dir}" -maxdepth 1 \( -type f -o -type l \) \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" -o -iname "*.bmp" \) -print0 2>/dev/null)
            fi
          '') expandedAdditionalDirs}

          if [[ ''${#WALLPAPERS[@]} -eq 0 ]]; then
            echo "No wallpapers found in any configured directory" >&2
            exit 1
          fi

          FUZZEL_INPUT=""
          for wallpaper in "''${WALLPAPERS[@]}"; do
            BASENAME="$(${pkgs.coreutils}/bin/basename "$wallpaper")"

            if [[ "$BASENAME" == "$CURRENT_WALLPAPER" ]]; then
              DISPLAY_NAME="● $BASENAME"
            else
              DISPLAY_NAME="○ $BASENAME"
            fi

            if [[ -n "$FUZZEL_INPUT" ]]; then
              FUZZEL_INPUT+="\n"
            fi
            FUZZEL_INPUT+="$DISPLAY_NAME"
          done

          SELECTED=$(echo -en "$FUZZEL_INPUT" | fuzzel --dmenu --prompt="Select wallpaper: ")

          if [[ -n "$SELECTED" ]]; then
            SELECTED_BASENAME="''${SELECTED#● }"
            SELECTED_BASENAME="''${SELECTED_BASENAME#○ }"

            echo "Selected wallpaper: $SELECTED_BASENAME"
            exec "${config.home.homeDirectory}/.local/bin/swaybg-enable-wallpaper" "$SELECTED_BASENAME"
          fi
        '';
      };

      home.file.".local/bin/scripts/swaybg-update-wallpaper" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash
          WALLPAPERS_DIR="${wallpapersDir}"
          STATE_FILE="${config.home.homeDirectory}/.local/state/swaybg/current-wallpaper"
          WALLPAPER=""

          RANDOMIZE=0
          if [[ "''${1:-}" == "--randomize" ]]; then
            RANDOMIZE=1
          else
            if [[ ! -f "$STATE_FILE" ]]; then
              RANDOMIZE=1
            else
              WALLPAPER="$(cat "$STATE_FILE" 2>/dev/null || echo "")"

              if [[ ! -f "$WALLPAPER" ]]; then
                RANDOMIZE=1
              fi
            fi
          fi

          if (( RANDOMIZE )); then
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
          fi

          if [ ! -f "$WALLPAPER" ]; then
            echo "Wallpaper file not found: $WALLPAPER" >&2
            exit 1
          fi

          mkdir -p "$(dirname "$STATE_FILE")"
          echo "$WALLPAPER" > "$STATE_FILE"

          echo "$WALLPAPER"
        '';
      };

      home.file.".local/bin/scripts/swaybg-start" = {
        executable = true;
        text = ''
          #!/usr/bin/env bash
          WALLPAPER="$(${config.home.homeDirectory}/.local/bin/scripts/swaybg-update-wallpaper "$@")"

          if [[ "$WALLPAPER" == "" ]]; then
            echo "No wallpaper found, aborting swaybg start"
            exit 1
          fi

          echo "Using wallpaper: $WALLPAPER"
          echo "Output: ${self.settings.output}"
          echo "Mode: ${self.settings.mode}"
          echo "Background color: ${self.settings.backgroundColor}"
          echo "Full command: ${pkgs.swaybg}/bin/swaybg -o ${self.settings.output} -i \"$WALLPAPER\" -m ${self.settings.mode} -c \"${self.settings.backgroundColor}\""

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
          ExecStart = "${config.home.homeDirectory}/.local/bin/swaybg-next-wallpaper";
        };
      };

      programs.niri.settings = lib.mkIf (self.isModuleEnabled "desktop.niri") {
        binds = with config.lib.niri.actions; {
          "Mod+Shift+Backslash" = {
            action = spawn (
              if self.settings.useSwitcher then "swaybg-switch-wallpaper" else "swaybg-next-wallpaper"
            );
            hotkey-overlay.title =
              if self.settings.useSwitcher then "UI:Switch wallpaper" else "UI:Next wallpaper";
          };
        };
      };

      home.persistence."${self.persist}" = {
        directories = [
          ".config/swaybg/wallpapers"
          ".local/state/swaybg"
        ];
      };
    };
}
