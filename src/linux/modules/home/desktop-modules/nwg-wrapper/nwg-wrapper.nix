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
  namespace = "home";

  settings = {
    usedTerminal = "xterm";
    usedShell = "bash";
    darkWallpaper = true;
    niriKeybindings = false;
    highlightMainColorOnDark = "#ddee99";
    highlightSecondColorOnDark = "#ddddcc";
    highlightMainColorOnLight = "#333388";
    highlightSecondColorOnLigh = "#336699";
    withBorder = true;
    withBackground = true;
  };

  configuration =
    context@{ config, options, ... }:
    let
      highlightMainColor =
        if self.settings.darkWallpaper then
          self.settings.highlightMainColorOnDark
        else
          self.settings.highlightMainColorOnLight;
      highlightSecondColor =
        if self.settings.darkWallpaper then
          self.settings.highlightSecondColorOnDark
        else
          self.settings.highlightSecondColorOnLight;
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

      generateKeybindingsContent =
        bindings:
        let
          mappedBindings = map (bind: {
            inherit (bind) desc;
            mappedKey =
              let
                keyWithoutMod =
                  if lib.hasPrefix "Mod+" bind.key then lib.removePrefix "Mod+" bind.key else bind.key;
              in
              mapBind keyWithoutMod;
          }) bindings;

          maxKeyWidth = lib.foldl (
            max: bind:
            let
              keyLength = builtins.stringLength bind.mappedKey;
            in
            if keyLength > max then keyLength else max
          ) 0 mappedBindings;

          padToWidth =
            str: width:
            let
              strLen = builtins.stringLength str;
              padding = width - strLen;
              spaces = lib.concatStrings (lib.genList (_: " ") padding);
            in
            str + spaces;

          formatBinding =
            bind:
            let
              paddedKey = padToWidth bind.mappedKey maxKeyWidth;
            in
            ''<span foreground="${highlightMainColor}">${paddedKey}</span>  <span foreground="${highlightSecondColor}">${bind.desc}</span>'';

          bindingLines = map formatBinding mappedBindings;
        in
        lib.concatStringsSep "\n" bindingLines;

      dateTimeArgs = [
        "-s"
        "%h/.local/bin/date-time.sh"
        "-c"
        "%h/.config/nwg-wrapper/date-time.css"
        "-r"
        "20000"
        "-p"
        "left"
        "-mr"
        "66"
        "-mt"
        "20"
        "-mb"
        "20"
        "-ml"
        "20"
      ]
      ++ displayArgs;

      keybindingsLeftArgs = [
        "-s"
        "%h/.local/bin/keybindings-left.sh"
        "-c"
        "%h/.config/nwg-wrapper/keybindings.css"
        "-p"
        "right"
        "-mt"
        "20"
        "-mb"
        "20"
        "-mr"
        "370"
      ]
      ++ displayArgs;

      keybindingsRightArgs = [
        "-s"
        "%h/.local/bin/keybindings-right.sh"
        "-c"
        "%h/.config/nwg-wrapper/keybindings.css"
        "-p"
        "right"
        "-mt"
        "20"
        "-mb"
        "20"
        "-mr"
        "20"
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

          <span font_size="9000" foreground="${highlightSecondColor}">$(fastfetch --pipe --logo-type none --terminal-format "${self.settings.usedTerminal}" --shell-format "${self.settings.usedShell}" --localip-show-ipv4 false --localip-show-ipv6 false | tail +3 | sed 's/\x1b\[[0-9;]*m//g' | sed 's/\x1b\[[0-9]*[A-Za-z]//g')</span>
          EOF
        '';
      };

      home.file.".local/bin/keybindings-left.sh" = lib.mkIf self.settings.niriKeybindings {
        executable = true;
        text = ''
          #!/usr/bin/env bash
          export LC_TIME=en_US.UTF-8

          cat << EOF
          ${generateKeybindingsContent splitKeybindings.left}
          EOF
        '';
      };

      home.file.".local/bin/keybindings-right.sh" = lib.mkIf self.settings.niriKeybindings {
        executable = true;
        text = ''
          #!/usr/bin/env bash
          export LC_TIME=en_US.UTF-8

          cat << EOF
          ${generateKeybindingsContent splitKeybindings.right}
          EOF
        '';
      };

      home.file.".config/nwg-wrapper/date-time.css" = {
        text = ''
          window {
              background-color: ${
                if self.settings.withBackground then "rgba(0, 0, 0, 0.4)" else "transparent"
              };
              border: ${if self.settings.withBorder then "1px solid black" else "none"};
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
                if self.settings.withBackground then "rgba(0, 0, 0, 0.4)" else "transparent"
              };
              border: ${if self.settings.withBorder then "1px solid black" else "none"};
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
                systemctl --user restart nx-nwg-wrapper-3 || true
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
          PartOf = [ "graphical-session.target" ];
          After = [
            "graphical-session.target"
            "nx-swaybg.service"
          ];
        };

        Service = {
          ExecStart = "${pkgs.nwg-wrapper}/bin/nwg-wrapper ${lib.escapeShellArgs dateTimeArgs}";
          Restart = "on-failure";
          RestartSec = "1";
          Type = "simple";
        };

        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
      };

      systemd.user.services.nx-nwg-wrapper-2 = lib.mkIf self.settings.niriKeybindings {
        Unit = {
          Description = "Background window daemon 2 - Keybindings Left";
          PartOf = [ "graphical-session.target" ];
          After = [
            "graphical-session.target"
            "nx-swaybg.service"
          ];
        };

        Service = {
          ExecStart = "${pkgs.nwg-wrapper}/bin/nwg-wrapper ${lib.escapeShellArgs keybindingsLeftArgs}";
          Restart = "on-failure";
          RestartSec = "1";
          Type = "simple";
        };

        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
      };

      systemd.user.services.nx-nwg-wrapper-3 = lib.mkIf self.settings.niriKeybindings {
        Unit = {
          Description = "Background window daemon 3 - Keybindings Right";
          PartOf = [ "graphical-session.target" ];
          After = [
            "graphical-session.target"
            "nx-swaybg.service"
          ];
        };

        Service = {
          ExecStart = "${pkgs.nwg-wrapper}/bin/nwg-wrapper ${lib.escapeShellArgs keybindingsRightArgs}";
          Restart = "on-failure";
          RestartSec = "1";
          Type = "simple";
        };

        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
      };
    };
}
