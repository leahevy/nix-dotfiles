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
  name = "nwg-wrapper";

  group = "desktop-modules";
  input = "linux";

  settings = {
    usedShell = "bash";
    niriKeybindings = false;
    withBorder = true;
    withBackground = true;
    centerOffset = null;
  };

  module = {
    linux.enabled = config: {
      nx.linux.desktop.common.graphicalSessionServices = [
        "nx-nwg-wrapper-1"
      ]
      ++ lib.optionals self.settings.niriKeybindings [
        "nx-nwg-wrapper-2"
      ];

      nx.linux.monitoring.journal-watcher.ignorePatterns = [
        {
          service = "nx-nwg-wrapper-1.service";
          string = "Failed with result 'exit-code'\.";
          user = true;
        }
        {
          tag = ".nwg-wrapper-wrapped";
          string = "Failed to set text .* from markup due to error parsing markup";
          user = true;
          unitless = true;
        }
      ]
      ++ lib.optionals self.settings.niriKeybindings [
        {
          service = "nx-nwg-wrapper-2.service";
          string = "Failed with result 'exit-code'\.";
          user = true;
        }
      ];
    };

    home =
      config:
      let
        seasonWallpaperInfo = self.inputs.nix-season-wallpaper.resolveWallpaperBySeason self.inputs.newestFlake.self;
        dailyWallpaperInfo = self.inputs.nix-season-wallpaper.resolveDailyWallpaper self.inputs.newestFlake.self;
        personPosition =
          if config.nx.themes.themes.season.enable then
            seasonWallpaperInfo.metadata.positionPerson
          else if config.nx.themes.themes.daily.enable then
            dailyWallpaperInfo.metadata.positionPerson
          else
            "center";
        isWidescreen = helpers.resolveFromHostOrUser config [ "displays" "mainIsWidescreen" ] false;
        effectiveCenterOffset =
          if self.settings.centerOffset != null then
            self.settings.centerOffset
          else
            (if isWidescreen then 3440 * 4 / 10 else 1920 * 4 / 10);
        terminal = config.nx.preferences.desktop.programs.terminal;
        highlightMainColor = config.nx.preferences.theme.colors.main.foregrounds.primary.html;
        highlightSecondColor = config.nx.preferences.theme.colors.main.foregrounds.emphasized.html;
        mainDisplay = self.host.displays.main or self.user.displays.main or null;
        displayArgs = lib.optionals (mainDisplay != null) [
          "-o"
          mainDisplay
        ];

        niriBinds = config.programs.niri.settings.binds or { };

        bindingMap = {
          XF86AudioRaiseVolume = "Vol+";
          XF86AudioLowerVolume = "Vol-";
          XF86AudioMute = "Mute";
          XF86AudioPlay = "Play";
          XF86AudioPause = "Pause";
          XF86AudioNext = "Next";
          XF86AudioPrev = "Prev";
          XF86MonBrightnessUp = "Bright+";
          XF86MonBrightnessDown = "Bright-";
          XF86PowerOff = "Power";
          XF86Sleep = "Sleep";
          XF86Wake = "Wake";
          XF86HomePage = "Home";
          XF86Calculator = "Calc";
          XF86Mail = "Mail";
          XF86Search = "Search";
        };
        mapBind = value: bindingMap.${value} or value;

        extractKeybindings =
          binds:
          let
            bindsList = lib.mapAttrsToList (key: value: {
              inherit key;
              fullTitle =
                if lib.isAttrs value && value ? "hotkey-overlay" && value."hotkey-overlay" ? "title" then
                  value."hotkey-overlay"."title"
                else
                  "Unknown";
            }) binds;

            validBinds = builtins.filter (
              bind: bind.fullTitle != "Unknown" && !(lib.hasPrefix "XF86" bind.key)
            ) bindsList;

            parseTitle =
              bind:
              let
                titleParts = lib.splitString ":" bind.fullTitle;
                hasGroup = builtins.length titleParts >= 2;
                group = if hasGroup then builtins.head titleParts else "Other";
                desc = if hasGroup then lib.concatStringsSep ":" (lib.drop 1 titleParts) else bind.fullTitle;
              in
              bind // { inherit group desc; };

            parsedBinds = map parseTitle validBinds;

            groupedByGroup = lib.groupBy (bind: bind.group) parsedBinds;
            sortedGroups = lib.mapAttrsToList (group: bindings: {
              inherit group;
              bindings = builtins.sort (a: b: a.key < b.key) bindings;
            }) groupedByGroup;
            sortedGroupsByName = builtins.sort (a: b: a.group < b.group) sortedGroups;
            flattenedBinds = lib.concatMap (group: group.bindings) sortedGroupsByName;
          in
          flattenedBinds;

        keybindingsList = extractKeybindings niriBinds;

        splitKeybindings =
          let
            totalCount = builtins.length keybindingsList;
            halfCount = totalCount / 2;
            firstHalf = lib.take halfCount keybindingsList;
            secondHalf = lib.drop halfCount keybindingsList;
          in
          {
            left = firstHalf;
            right = secondHalf;
          };

        generateTwoColumnContent =
          leftBindings: rightBindings:
          let
            columnGap = 4;

            prepBind =
              bind:
              let
                keyWithoutMod =
                  if lib.hasPrefix "Mod+" bind.key then lib.removePrefix "Mod+" bind.key else bind.key;
              in
              {
                inherit (bind) desc;
                mappedKey = mapBind keyWithoutMod;
              };

            leftMapped = map prepBind leftBindings;
            rightMapped = map prepBind rightBindings;
            allMapped = leftMapped ++ rightMapped;

            maxKeyWidth = lib.foldl (
              max: bind:
              let
                kl = builtins.stringLength bind.mappedKey;
              in
              if kl > max then kl else max
            ) 0 allMapped;

            maxLeftDescWidth = lib.foldl (
              max: bind:
              let
                dl = builtins.stringLength bind.desc;
              in
              if dl > max then dl else max
            ) 0 leftMapped;

            padToWidth =
              str: width:
              let
                strLen = builtins.stringLength str;
                padding = width - strLen;
                spaces = lib.concatStrings (lib.genList (_: " ") (if padding > 0 then padding else 0));
              in
              str + spaces;

            formatLeft =
              bind:
              let
                paddedKey = padToWidth bind.mappedKey maxKeyWidth;
                paddedDesc = padToWidth bind.desc maxLeftDescWidth;
              in
              ''<span foreground="${highlightMainColor}">${paddedKey}</span>  <span foreground="${highlightSecondColor}">${paddedDesc}</span>'';

            formatRight =
              bind:
              let
                paddedKey = padToWidth bind.mappedKey maxKeyWidth;
              in
              ''<span foreground="${highlightMainColor}">${paddedKey}</span>  <span foreground="${highlightSecondColor}">${bind.desc}</span>'';

            leftCount = builtins.length leftMapped;
            rightCount = builtins.length rightMapped;
            maxCount = if leftCount > rightCount then leftCount else rightCount;

            emptyBind = {
              mappedKey = "";
              desc = "";
            };
            paddedLeft = leftMapped ++ lib.genList (_: emptyBind) (maxCount - leftCount);
            paddedRight = rightMapped ++ lib.genList (_: emptyBind) (maxCount - rightCount);

            gapSpaces = lib.concatStrings (lib.genList (_: " ") columnGap);

            formatRow =
              i:
              let
                l = builtins.elemAt paddedLeft i;
                r = builtins.elemAt paddedRight i;
              in
              (formatLeft l) + gapSpaces + (formatRight r);

            rows = lib.genList formatRow maxCount;
          in
          lib.concatStringsSep "\n" rows;

        dateTimeArgs = [
          "-s"
          "%h/.local/bin/date-time.sh"
          "-c"
          "%h/.config/nwg-wrapper/date-time.css"
          "-r"
          "20000"
          "-p"
          "left"
          "-mt"
          "20"
          "-mb"
          "20"
        ]
        ++ [
          "-ml"
          (if personPosition == "left" then builtins.toString effectiveCenterOffset else "20")
        ]
        ++ displayArgs;

        keybindingsArgs = [
          "-s"
          "%h/.local/bin/keybindings-all.sh"
          "-c"
          "%h/.config/nwg-wrapper/keybindings.css"
          "-p"
          "right"
          "-mt"
          "20"
          "-mb"
          "20"
        ]
        ++ [
          "-mr"
          (if personPosition == "right" then builtins.toString effectiveCenterOffset else "20")
        ]
        ++ displayArgs;
      in
      {
        home.packages = with pkgs; [
          nwg-wrapper
          fastfetch
        ];

        home.file.".local/bin/date-time.sh" = {
          executable = true;
          text = ''
            #!/usr/bin/env bash
            export LC_TIME=en_US.UTF-8

            date_line=$(date "+%A, %d %B")
            time_line=$(date "+%l:%M %p")

            cat << EOF
            <span foreground="${highlightMainColor}">$date_line</span>
            <span foreground="${highlightSecondColor}" weight="bold">$time_line</span>

            <span font_size="6000" foreground="${highlightMainColor}">$(fastfetch --pipe --structure "NoLogo" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/\x1b\[[0-9]*[A-Za-z]//g')</span>

            <span font_size="9000" foreground="${highlightSecondColor}">$(fastfetch --pipe --logo-type none --config "${self.user.home}/.config/nwg-wrapper/details-config.json" | sed 's/\x1b\[[0-9;]*m//g' | sed 's/\x1b\[[0-9]*[A-Za-z]//g')</span>
            EOF
          '';
        };

        home.file.".config/nwg-wrapper/details-config.json" = {
          text = ''
            {
              "modules": [
                { "type": "os" },
                { "type": "kernel" },
                { "type": "uptime" },
                { "type": "packages" },
                { "type": "shell", "format": "${self.settings.usedShell}" },
                { "type": "display" },
                { "type": "wm" },
                { "type": "theme" },
                { "type": "icons" },
                { "type": "font" },
                { "type": "cursor" },
                { "type": "terminal", "format": "${terminal.name}" },
                { "type": "cpu" },
                { "type": "gpu" },
                { "type": "memory" },
                { "type": "swap" },
                { "type": "disk" },
                { "type": "locale" }
              ]
            }
          '';
        };

        home.file.".local/bin/keybindings-all.sh" = lib.mkIf self.settings.niriKeybindings {
          executable = true;
          text = ''
            #!/usr/bin/env bash
            export LC_TIME=en_US.UTF-8

            cat << EOF
            ${generateTwoColumnContent splitKeybindings.left splitKeybindings.right}
            EOF
          '';
        };

        home.file.".config/nwg-wrapper/date-time.css" = {
          text = ''
            window {
                background-color: ${
                  if self.settings.withBackground then
                    let
                      bgColor = config.nx.preferences.theme.colors.main.backgrounds.primary.html;
                      rgb = lib.removePrefix "#" bgColor;
                      r = builtins.toString (builtins.fromTOML "x = 0x${builtins.substring 0 2 rgb}").x;
                      g = builtins.toString (builtins.fromTOML "x = 0x${builtins.substring 2 2 rgb}").x;
                      b = builtins.toString (builtins.fromTOML "x = 0x${builtins.substring 4 2 rgb}").x;
                    in
                    "rgba(${r}, ${g}, ${b}, 0.7)"
                  else
                    "transparent"
                };
                border: ${
                  if self.settings.withBorder then
                    "1px solid ${config.nx.preferences.theme.colors.separators.normal.html}"
                  else
                    "none"
                };
            }

            label {
                font-family: monospace;
                font-size: 38px;
                padding: 15px;
                margin-left: 80px;
            }
          '';
        };

        home.file.".config/nwg-wrapper/keybindings.css" = lib.mkIf self.settings.niriKeybindings {
          text = ''
            window {
                background-color: ${
                  if self.settings.withBackground then
                    let
                      bgColor = config.nx.preferences.theme.colors.main.backgrounds.primary.html;
                      rgb = lib.removePrefix "#" bgColor;
                      r = builtins.toString (builtins.fromTOML "x = 0x${builtins.substring 0 2 rgb}").x;
                      g = builtins.toString (builtins.fromTOML "x = 0x${builtins.substring 2 2 rgb}").x;
                      b = builtins.toString (builtins.fromTOML "x = 0x${builtins.substring 4 2 rgb}").x;
                    in
                    "rgba(${r}, ${g}, ${b}, 0.7)"
                  else
                    "transparent"
                };
                border: ${
                  if self.settings.withBorder then
                    "1px solid ${config.nx.preferences.theme.colors.separators.normal.html}"
                  else
                    "none"
                };
            }

            label {
                font-family: monospace;
                font-size: 10px;
                padding: 15px;
                margin-top: 10px;
                margin-bottom: 10px;
                margin-right: 5px;
                margin-left: 5px;
            }
          '';
        };

        home.file.".local/bin/nwg-wrapper-restart" = {
          text = ''
            #!/usr/bin/env bash
            systemctl --user restart nx-nwg-wrapper-1 || true
            ${
              if self.settings.niriKeybindings then
                ''
                  systemctl --user restart nx-nwg-wrapper-2 || true
                ''
              else
                ""
            }
          '';
          executable = true;
        };

        systemd.user.services.nx-nwg-wrapper-1 = {
          Unit = {
            Description = "Background window daemon 1";
            After = [ "nx-swaybg.service" ];
            StartLimitIntervalSec = 0;
          };

          Service = {
            ExecStart = "${pkgs.nwg-wrapper}/bin/nwg-wrapper ${lib.escapeShellArgs dateTimeArgs}";
            Restart = "always";
            RestartSec = "30s";
            Type = "simple";
          };

          Install = {
            WantedBy = [ "graphical-session.target" ];
          };
        };

        systemd.user.services.nx-nwg-wrapper-2 = lib.mkIf self.settings.niriKeybindings {
          Unit = {
            Description = "Background window daemon 2 - Keybindings";
            After = [
              "nx-swaybg.service"
              "nx-nwg-wrapper-1.service"
            ];
            StartLimitIntervalSec = 0;
          };

          Service = {
            ExecStart = "${pkgs.nwg-wrapper}/bin/nwg-wrapper ${lib.escapeShellArgs keybindingsArgs}";
            Restart = "always";
            RestartSec = "30s";
            Type = "simple";
          };

          Install = {
            WantedBy = [ "graphical-session.target" ];
          };
        };
      };
  };
}
