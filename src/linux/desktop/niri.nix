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

  options = {
    autostartPrograms = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Programs to autostart when niri starts.";
    };
    scratchpadCommand = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Command to run inside the scratchpad terminal. If null, opens a plain terminal.";
    };
    lateWindowRules = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            match = {
              app-id = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
              };
              title = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
              };
            };
            skipStaticRule = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Skip generating a corresponding static niri window rule.";
            };
            apply = {
              float = lib.mkOption {
                type = lib.types.nullOr lib.types.bool;
                default = null;
              };
              workspace = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
              };
              focus = lib.mkOption {
                type = lib.types.nullOr lib.types.bool;
                default = null;
              };
              width = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
              };
              height = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
              };
            };
          };
        }
      );
      default = [ ];
      description = "Window rules applied via IPC when app-id/title change after window creation.";
    };
    powerMenuChecks = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            condition = lib.mkOption {
              type = lib.types.str;
              description = "Shell command that exits 0 to block power actions.";
            };
            message = lib.mkOption {
              type = lib.types.str;
              description = "Message shown via notify-send when the condition is met.";
            };
          };
        }
      );
      default = [ ];
      description = "Checks run before power menu actions. If a condition exits 0, the message is shown and the menu is blocked.";
    };
    appIdMapping = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Map of custom app-ids to real app-ids for icon resolution.";
    };
    nextWallpaperCommand = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Command to switch to the next wallpaper on workspace change.";
    };
    resetWallpaperCommand = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Command to reset the wallpaper on workspace change.";
    };
    windowOpenShader = lib.mkOption {
      type = lib.types.str;
      default = "roll-drop";
    };
    windowOpenShaderDuration = lib.mkOption {
      type = lib.types.int;
      default = 170;
    };
    windowCloseShader = lib.mkOption {
      type = lib.types.str;
      default = "swipe-window";
    };
    windowCloseShaderDuration = lib.mkOption {
      type = lib.types.int;
      default = 120;
    };
    windowResizeShader = lib.mkOption {
      type = lib.types.str;
      default = "unravel";
    };
    disableNewAppSwitcher = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    addRestartShortcut = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    screenshotBasePictureDir = lib.mkOption {
      type = lib.types.str;
      default = "screenshots";
    };
    mainDisplayScale = lib.mkOption {
      type = lib.types.float;
      default = 1.0;
    };
    secondaryDisplayScale = lib.mkOption {
      type = lib.types.float;
      default = 1.0;
    };
    applicationsToStart = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
    delayedApplicationsToStart = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
    };
    activeColor = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    inactiveColor = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    switchBackgroundOnWorkspaceChange = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    modKey = lib.mkOption {
      type = lib.types.str;
      default = "Super";
    };
    modKeyNested = lib.mkOption {
      type = lib.types.str;
      default = "Alt";
    };
    honorXDGActivation = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    deactivateUnfocusedWindows = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    displayModes = lib.mkOption {
      type = lib.types.submodule {
        options = {
          main = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
          secondary = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
        };
      };
      default = {
        main = null;
        secondary = null;
      };
    };
  };

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
        wayland = true;
        xwayland-satellite = true;
        greetd = {
          package = pkgs.niri;
          cmdline = "niri-session";
        };
        fuzzel = true;
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
          commandline = "swaylock --daemonize --clock --indicator --indicator-idle-visible --grace-no-mouse --effect-blur 8x2 --ring-color <RING_COLOR> --indicator-radius 110 --effect-greyscale --submit-on-touch --screenshots --inside-wrong-color <INSIDE_WRONG_COLOR> --text-wrong-color <TEXT_WRONG_COLOR> --inside-ver-color <INSIDE_VER_COLOR> --text-ver-color <TEXT_VER_COLOR> --ring-ver-color <RING_VER_COLOR> --ring-wrong-color <RING_WRONG_COLOR> --ring-clear-color <RING_CLEAR_COLOR> --text-clear-color <TEXT_CLEAR_COLOR> --inside-clear-color <INSIDE_CLEAR_COLOR> --line-uses-inside --line-uses-ring";
        };
        swaylock = {
          useEffects = true;
        };
        swaybg = true;
        nwg-wrapper = {
          niriKeybindings = true;
        };
        wlsunset = true;
        bongocat = true;
        programs = {
          installOfficeSuite = true;
          installSystemSettings = true;
        };
        clipboard-persistence = true;
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

  assertions = [
    {
      assertion = (self.host.displays.main or self.user.displays.main or null) != null;
      message = "Requires host.displays.main or user.displays.main (for standalone) to be configured!";
    }
    {
      assertion = self.user.settings.terminal != null;
      message = "user.settings.terminal is not set!";
    }
  ];

  module = {
    home =
      config:
      let
        parseKdlShader =
          kdlContent: sectionName:
          let
            lines = lib.splitString "\n" kdlContent;
            countChar = c: s: (builtins.length (lib.splitString c s)) - 1;
            result =
              builtins.foldl'
                (
                  acc: line:
                  if acc.done then
                    acc
                  else if acc.capturing then
                    let
                      m = builtins.match ''(.*)"[[:space:]]*'' line;
                    in
                    if m != null then
                      acc
                      // {
                        done = true;
                        shader = acc.shader + (builtins.elemAt m 0);
                        capturing = false;
                      }
                    else
                      acc // { shader = acc.shader + line + "\n"; }
                  else if acc.inSection then
                    let
                      newDepth = acc.depth + (countChar "{" line) - (countChar "}" line);
                      rawMatch = builtins.match ''.*custom-shader[[:space:]]+r"(.*)'' line;
                      strMatch = builtins.match ''.*custom-shader[[:space:]]+"(.*)'' line;
                      shaderMatch = if rawMatch != null then rawMatch else strMatch;
                    in
                    if shaderMatch != null then
                      let
                        rest = builtins.elemAt shaderMatch 0;
                        endMatch = builtins.match ''(.*)"[[:space:]]*'' rest;
                      in
                      if endMatch != null then
                        acc
                        // {
                          done = true;
                          shader = builtins.elemAt endMatch 0;
                        }
                      else
                        acc
                        // {
                          capturing = true;
                          shader = if rest != "" then rest + "\n" else "";
                        }
                    else if newDepth <= 0 then
                      acc
                      // {
                        inSection = false;
                        depth = 0;
                      }
                    else
                      acc // { depth = newDepth; }
                  else
                    let
                      m = builtins.match ("[[:space:]]*" + sectionName + "[[:space:]]*[{].*") line;
                    in
                    if m != null then
                      acc
                      // {
                        inSection = true;
                        depth = 1;
                      }
                    else
                      acc
                )
                {
                  inSection = false;
                  capturing = false;
                  shader = "";
                  done = false;
                  depth = 0;
                }
                lines;
          in
          result.shader;

        getShader =
          name:
          let
            parts = lib.splitString "/" name;
            animation = builtins.elemAt parts 0;
            section = builtins.elemAt parts 1;
          in
          parseKdlShader (builtins.readFile "${self.inputs.nirimation}/animations/${animation}.kdl") section;

        lateRules = (self.options config).lateWindowRules;
        hasLateRules = lateRules != [ ];

        lateRulesJson = pkgs.writeText "niri-late-rules.json" (builtins.toJSON lateRules);

        lateRulesScript =
          pkgs.writers.writePython3 "niri-late-rules"
            {
              flakeIgnore = [ "E501" ];
            }
            ''
              import json
              import logging
              import subprocess
              import sys
              import time

              NIRI = "${pkgs.niri}/bin/niri"
              logging.basicConfig(
                  level=logging.INFO,
                  format="%(asctime)s %(levelname)s %(message)s",
                  datefmt="%H:%M:%S",
              )
              log = logging.getLogger("niri-late-rules")


              def wait_for_niri(timeout=30):
                  deadline = time.monotonic() + timeout
                  attempt = 0
                  while time.monotonic() < deadline:
                      attempt += 1
                      result = subprocess.run(
                          [NIRI, "msg", "--json", "outputs"],
                          capture_output=True, text=True,
                      )
                      if result.returncode == 0:
                          try:
                              outputs = json.loads(result.stdout)
                              if len(outputs) > 0:
                                  log.info(
                                      "niri ready after %d attempt(s):"
                                      " %d output(s) confirmed",
                                      attempt, len(outputs),
                                  )
                                  return True
                          except json.JSONDecodeError:
                              pass
                      log.info(
                          "waiting for niri (attempt %d, %.0fs remaining)",
                          attempt, deadline - time.monotonic(),
                      )
                      time.sleep(1)
                  return False


              def load_rules():
                  with open("${lateRulesJson}") as f:
                      return json.load(f)


              def matches(rule, app_id, title):
                  m = rule["match"]
                  mid = m.get("app-id")
                  mtitle = m.get("title")
                  if mid is None and mtitle is None:
                      return False
                  if mid is not None and mid != app_id:
                      return False
                  if mtitle is not None and mtitle != title:
                      return False
                  return True


              def niri_action(app_id, title, *args):
                  cmd = [NIRI, "msg", "action", *args]
                  log.info(
                      "  niri cmd: %s (window: app-id=%s title=%s)",
                      " ".join(args), app_id, title,
                  )
                  result = subprocess.run(cmd, capture_output=True, text=True)
                  if result.returncode != 0:
                      log.warning(
                          "  niri cmd failed: %s", result.stderr.strip(),
                      )


              def apply_rule(rule, wid, app_id, title):
                  a = rule["apply"]
                  m = rule["match"]
                  log.info(
                      "matched rule (app-id=%s title=%s) on window %d"
                      " (app-id=%s title=%s)",
                      m.get("app-id"), m.get("title"), wid, app_id, title,
                  )
                  wid_s = str(wid)
                  if a.get("float") is True:
                      niri_action(
                          app_id, title,
                          "move-window-to-floating", "--id", wid_s,
                      )
                  if a.get("workspace"):
                      niri_action(
                          app_id, title,
                          "move-window-to-workspace",
                          "--window-id", wid_s,
                          "--focus", "false",
                          a["workspace"],
                      )
                  if a.get("width"):
                      niri_action(
                          app_id, title,
                          "set-window-width", "--id", wid_s, a["width"],
                      )
                  if a.get("height"):
                      niri_action(
                          app_id, title,
                          "set-window-height", "--id", wid_s, a["height"],
                      )
                  if a.get("focus") is True:
                      niri_action(
                          app_id, title,
                          "focus-window", "--id", wid_s,
                      )


              def mark_existing(rules, handled):
                  result = subprocess.run(
                      [NIRI, "msg", "--json", "windows"],
                      capture_output=True, text=True,
                  )
                  if result.returncode != 0:
                      log.warning("failed to list existing windows")
                      return
                  for win in json.loads(result.stdout):
                      wid = win["id"]
                      app_id = win.get("app_id", "")
                      title = win.get("title", "")
                      for rule in rules:
                          if matches(rule, app_id, title):
                              handled.add(wid)
                              log.info(
                                  "marked existing window %d (app-id=%s title=%s)"
                                  " as handled",
                                  wid, app_id, title,
                              )
                              break


              def main():
                  rules = load_rules()
                  log.info("started with %d late window rule(s)", len(rules))

                  if not wait_for_niri():
                      log.error("niri not ready after 30s, exiting")
                      sys.exit(1)

                  handled = set()
                  mark_existing(rules, handled)

                  proc = subprocess.Popen(
                      [NIRI, "msg", "--json", "event-stream"],
                      stdout=subprocess.PIPE,
                      text=True,
                  )

                  for line in proc.stdout:
                      try:
                          event = json.loads(line)
                      except json.JSONDecodeError:
                          continue

                      if "WindowOpenedOrChanged" in event:
                          win = event["WindowOpenedOrChanged"]["window"]
                          wid = win["id"]
                          if wid in handled:
                              continue
                          app_id = win.get("app_id", "")
                          title = win.get("title", "")
                          for rule in rules:
                              if matches(rule, app_id, title):
                                  apply_rule(rule, wid, app_id, title)
                                  handled.add(wid)
                                  break

                      elif "WindowClosed" in event:
                          wid = event["WindowClosed"]["id"]
                          handled.discard(wid)

                  log.error("event stream ended unexpectedly")
                  sys.exit(1)


              if __name__ == "__main__":
                  main()
            '';

        mainDisplay = self.host.displays.main or self.user.displays.main or null;
        secondaryDisplay = self.host.displays.secondary or self.user.displays.secondary or null;
        programsConfig = config.nx.preferences.desktop.programs;
        terminal = programsConfig.terminal;
        additionalTerminal = programsConfig.additionalTerminal;
        terminalWindowClass =
          if terminal.desktopFile != null then lib.removeSuffix ".desktop" terminal.desktopFile else null;
        effectiveAppIdMapping =
          (self.options config).appIdMapping
          // lib.optionalAttrs (terminalWindowClass != null) {
            "org.nx.scratchpad" = terminalWindowClass;
          };
        scratchpadRunWithClass =
          class: cmd:
          lib.escapeShellArgs (
            helpers.runWithAbsolutePath config terminal (terminal.openRunWithClass class) cmd
          );
        scratchpadOpenWithClass =
          class:
          lib.escapeShellArgs (
            helpers.runWithAbsolutePath config terminal (terminal.openWithClass class) [ ]
          );
        terminalCmd = lib.escapeShellArgs (
          helpers.runWithAbsolutePath config additionalTerminal additionalTerminal.openCommand [ ]
        );
        appLauncher =
          if programsConfig.appLauncher == null then
            throw "niri requires an application launcher (e.g., enable linux.desktop-modules.fuzzel)"
          else
            programsConfig.appLauncher;
        appLauncherCmd = lib.escapeShellArgs (
          helpers.runWithAbsolutePath config appLauncher appLauncher.openCommand [ ]
        );
        appLauncherDmenu =
          opts:
          lib.escapeShellArgs (helpers.runWithAbsolutePath config appLauncher appLauncher.dmenuCommand opts);
        appLauncherDmenuRaw =
          opts:
          lib.concatStringsSep " " (
            helpers.runWithAbsolutePath config appLauncher appLauncher.dmenuCommand opts
          );
        appLauncherDmenuIndex =
          opts:
          lib.escapeShellArgs (
            helpers.runWithAbsolutePath config appLauncher appLauncher.dmenuIndexCommand opts
          );
        requiredApps =
          let
            scratchpadCmd = (self.options config).scratchpadCommand;
          in
          [
            (
              if scratchpadCmd != null then
                scratchpadRunWithClass "org.nx.scratchpad" scratchpadCmd
              else
                scratchpadOpenWithClass "org.nx.scratchpad"
            )
          ];
        delayedRequiredApps = [ ];
        theme = config.nx.preferences.theme;
        activeColor =
          if (self.options config).activeColor != null then
            (self.options config).activeColor
          else
            theme.colors.main.foregrounds.primary.html;
        inactiveColor =
          if (self.options config).inactiveColor != null then
            (self.options config).inactiveColor
          else
            theme.colors.main.backgrounds.secondary.html;

        deploymentLockCheck = {
          condition = ''[[ -d "/tmp/.nx-deployment-lock" ]]'';
          message = "Cannot access power options while NX deployment is running!";
        };

        powerMenuChecksScript = lib.concatMapStrings (check: ''
          if ${check.condition} 2>/dev/null; then
              ${self.notifyUser {
                inherit pkgs;
                title = "Power Menu";
                body = check.message;
                icon = "dialog-error";
                urgency = "critical";
                validation = { inherit config; };
              }}
              exit 1
          fi
        '') ([ deploymentLockCheck ] ++ (self.options config).powerMenuChecks);

        screenshotPath =
          let
            xdgConfig = self.getModuleConfig "xdg.user-dirs";
            picturesDir =
              if xdgConfig != { } && xdgConfig ? pictures then
                "${self.user.home}/${xdgConfig.pictures}"
              else
                "${self.user.home}/Pictures";
          in
          "${picturesDir}/${(self.options config).screenshotBasePictureDir}/%Y_%m_%d_%H%M%S.png";

        screenshotDir = builtins.dirOf screenshotPath;

        generateStartupCommands = apps: map (app: { sh = "sleep 1 && uwsm app -- ${app}"; }) apps;

        generateDelayedStartupCommands = apps: map (app: { sh = "sleep 6 && uwsm app -- ${app}"; }) apps;

        startupApps = requiredApps ++ (self.options config).applicationsToStart;
        autostartPrograms = (self.options config).autostartPrograms;
        delayedStartupApps =
          delayedRequiredApps ++ (self.options config).delayedApplicationsToStart ++ autostartPrograms;

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
        autostartDummies = map (
          prog:
          let
            firstWord = builtins.head (lib.splitString " " prog);
            baseName = lib.last (lib.splitString "/" firstWord);
          in
          pkgs.runCommand "niri-autostart-${lib.strings.sanitizeDerivationName baseName}" { } "mkdir $out"
        ) (startupApps ++ delayedStartupApps);
      in
      {
        home.packages = [
          pkgs.jq
        ]
        ++ autostartDummies;

        home.file.".local/bin/niri-scratchpad" = {
          source = self.file "niri-scratchpad/niri-scratchpad.sh";
          executable = true;
        };

        home.file.".local/bin/restart-niri" = lib.mkIf (self.options config).addRestartShortcut {
          executable = true;
          text = ''
            #!/usr/bin/env bash

            choice=$(echo -e "Yes\nNo" | ${
              appLauncherDmenu {
                prompt = "Restart Niri session? ";
                width = 25;
                lines = 2;
              }
            })

            case "$choice" in
              "Yes")
                ${pkgs.uwsm}/bin/uwsm stop
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

            # Power menu using app launcher
            # Usage: power-menu.sh

            set -euo pipefail

            ${powerMenuChecksScript}

            action=$(echo -e "Poweroff\nReboot" | ${
              appLauncherDmenu {
                prompt = "Power actions: ";
                width = 25;
                lines = 2;
              }
            })

            if [[ -z "$action" ]]; then
                exit 0
            fi

            declare -A commands=(
                ["Poweroff"]="systemctl poweroff"
                ["Reboot"]="systemctl reboot"
            )

            confirm=$(echo -e "Yes\nNo" | ${
              appLauncherDmenuRaw {
                prompt = "$action? ";
                width = 20;
                lines = 2;
              }
            })

            if [[ "$confirm" == "Yes" ]]; then
                ''${commands[$action]}
            fi
          '';
        };

        home.file.".local/bin/scratchpad-terminal" =
          let
            scratchpadCmd = (self.options config).scratchpadCommand;
          in
          {
            executable = true;
            text = ''
              #!/usr/bin/env bash
              exec ${
                if scratchpadCmd != null then
                  scratchpadRunWithClass "org.nx.scratchpad" scratchpadCmd
                else
                  scratchpadOpenWithClass "org.nx.scratchpad"
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
                  lib.mapAttrsToList (k: v: "\"${k}\") echo \"${v}\" ;;") effectiveAppIdMapping
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

            result=$(printf "%b\n" "''${window_titles[@]}" | ${appLauncherDmenuIndex { }})

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
              let
                nextCmd = (self.options config).nextWallpaperCommand;
                resetCmd = (self.options config).resetWallpaperCommand;
              in
              lib.optionalString (nextCmd != null || resetCmd != null) (
                if (self.options config).switchBackgroundOnWorkspaceChange then
                  lib.optionalString (nextCmd != null) ''
                    if [[ "$CHANGE_WALLPAPER" == "true" ]]; then
                      ${nextCmd}
                    fi
                  ''
                else
                  lib.optionalString (resetCmd != null) ''
                    if [[ "$CHANGE_WALLPAPER" == "true" ]]; then
                      ${resetCmd}
                    fi
                  ''
              )
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

        systemd.user.services = lib.optionalAttrs hasLateRules {
          "niri-late-rules" = {
            Unit = {
              Description = "Niri late window rules";
              PartOf = [ "graphical-session.target" ];
              After = [ "graphical-session.target" ];
              StartLimitIntervalSec = 0;
            };
            Service = {
              ExecStart = "${lateRulesScript}";
              Restart = "always";
              RestartSec = "2s";
              Type = "simple";
            };
            Install = {
              WantedBy = [ "graphical-session.target" ];
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
              (lib.mkIf (self.options config).honorXDGActivation {
                honor-xdg-activation-with-invalid-serial = [ ];
              })
              (lib.mkIf (self.options config).deactivateUnfocusedWindows {
                deactivate-unfocused-windows = [ ];
              })
            ];

            spawn-at-startup =
              (generateStartupCommands startupApps) ++ (generateDelayedStartupCommands delayedStartupApps);

            input = {
              mod-key = (self.options config).modKey;
              mod-key-nested = (self.options config).modKeyNested;
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
              let
                stylix = config.nx.common.style.stylix;
              in
              if stylix.resolvedCursor or null != null then
                {
                  theme = stylix.resolvedCursor.name;
                  size = stylix.resolvedCursor.size;
                }
              else
                { }
            );

            overview = {
              zoom = 0.93;
              backdrop-color = config.nx.preferences.theme.colors.main.backgrounds.primary.html;
            };

            clipboard = {
              disable-primary = false;
            };

            layout = {
              background-color = config.nx.preferences.theme.colors.main.backgrounds.primary.html;
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
                  scale = (self.options config).mainDisplayScale;
                  mode =
                    lib.mkIf ((self.options config).displayModes.main != null)
                      (self.options config).displayModes.main;
                };
              })
              (lib.mkIf (secondaryDisplay != null) {
                ${secondaryDisplay} = {
                  scale = (self.options config).secondaryDisplayScale;
                  mode =
                    lib.mkIf ((self.options config).displayModes.secondary != null)
                      (self.options config).displayModes.secondary;
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
                  "Alt+Tab" = lib.mkIf (self.options config).disableNewAppSwitcher {
                    action = spawn-sh "nop";
                  };

                  "Alt+Shift+Tab" = lib.mkIf (self.options config).disableNewAppSwitcher {
                    action = spawn-sh "nop";
                  };

                  "Mod+Return" = {
                    action = spawn-sh terminalCmd;
                    hotkey-overlay.title = "Apps:Terminal";
                  };

                  "Mod+Space" = {
                    action = spawn-sh appLauncherCmd;
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
                    action.screenshot = {
                      show-pointer = false;
                    };
                    hotkey-overlay.title = "Screenshot:Screenshot";
                  };

                  "Shift+Print" = {
                    action.screenshot-window = {
                      write-to-disk = true;
                    };
                    hotkey-overlay.title = "Screenshot:Window screenshot";
                  };

                  "Mod+P" = {
                    action.screenshot = {
                      show-pointer = false;
                    };
                    hotkey-overlay.title = "Screenshot:Screenshot";
                  };

                  "Mod+Shift+P" = {
                    action.screenshot-window = {
                      write-to-disk = true;
                    };
                    hotkey-overlay.title = "Screenshot:Window screenshot";
                  };

                  "Mod+Ctrl+P" = {
                    action = spawn-sh (
                      lib.escapeShellArgs (
                        (helpers.terminalPrefixIf config programsConfig.fileBrowser)
                        ++ (programsConfig.fileBrowser.openFileCommand screenshotDir)
                      )
                    );
                    hotkey-overlay.title = "Screenshot:Open screenshots folder";
                  };

                  "Mod+O" = {
                    action = toggle-overview;
                    hotkey-overlay.title = "Windows:Toggle overview";
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

                  "Mod+Ctrl+Alt+R" = lib.mkIf (self.options config).addRestartShortcut {
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
                  easing =
                    if (self.options config).windowOpenShader != null then
                      {
                        duration-ms = (self.options config).windowOpenShaderDuration;
                        curve = "linear";
                      }
                    else
                      {
                        duration-ms = 150;
                        curve = "ease-out-expo";
                      };
                };
              }
              // lib.optionalAttrs ((self.options config).windowOpenShader != null) {
                custom-shader = getShader "${(self.options config).windowOpenShader}/window-open";
              };

              window-close = {
                kind = {
                  easing =
                    if (self.options config).windowCloseShader != null then
                      {
                        duration-ms = (self.options config).windowCloseShaderDuration;
                        curve = "linear";
                      }
                    else
                      {
                        duration-ms = 150;
                        curve = "ease-out-quad";
                      };
                };
              }
              // lib.optionalAttrs ((self.options config).windowCloseShader != null) {
                custom-shader = getShader "${(self.options config).windowCloseShader}/window-close";
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
              }
              // lib.optionalAttrs ((self.options config).windowResizeShader != null) {
                custom-shader = getShader "${(self.options config).windowResizeShader}/window-resize";
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
                matches = [ { app-id = "org.nx.scratchpad"; } ];
                default-column-width = {
                  proportion = 0.52;
                };
                default-window-height = {
                  proportion = 0.9;
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
                default-window-height = {
                  proportion = 0.9;
                };
                open-floating = true;
                open-focused = true;
              }
            ]
            ++ (map (
              rule:
              let
                m = rule.match;
                a = rule.apply;
                matchAttrs = lib.filterAttrs (_: v: v != null) {
                  inherit (m) app-id title;
                };
              in
              {
                matches = [ matchAttrs ];
              }
              // lib.optionalAttrs (a.float == true) { open-floating = true; }
              // lib.optionalAttrs (a.workspace != null) { open-on-workspace = a.workspace; }
              // lib.optionalAttrs (a.focus != true) { open-focused = false; }
            ) (lib.filter (r: !r.skipStaticRule) lateRules));
          };
        };
      };

    linux.system = config: {
      programs.niri = {
        enable = true;
        package = pkgs.niri;
      };

      services.displayManager.sessionPackages = lib.mkForce [ ];

      environment.systemPackages = with pkgs; [
        wev
        wayland-utils
        wl-clipboard
        wlr-randr
        grim
        slurp
        wf-recorder
      ];

      security.pam.services.swaylock = { };
    };
  };
}
