args@{
  lib,
  pkgs,
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
    autoTiler = lib.mkOption {
      type = lib.types.submodule {
        options = {
          enable = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether to run the auto-tiler service.";
          };
          windowsPerColumn = lib.mkOption {
            type = lib.types.int;
            default = 2;
            description = "Maximum number of windows stacked vertically in a column before a new column is started.";
          };
          firstColumnStacks = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether the first column participates in auto-stacking or always remains a single full-height window.";
          };
          columnLimit = lib.mkOption {
            type = lib.types.int;
            default = 0;
            description = "Number of columns auto-tiling applies to, or 0 for unlimited.";
          };
          applyOnMove = lib.mkOption {
            type = lib.types.bool;
            default = true;
            description = "Whether to re-apply tiling when a window is moved to a different workspace.";
          };
          ignoredWorkspaces = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ "scratch" ];
            description = "Workspace names where auto-tiling is never applied.";
          };
          ignoredAppIds = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "App-ids excluded from auto-tiling and from being stacked with other windows.";
          };
          startupDelayMs = lib.mkOption {
            type = lib.types.int;
            default = 1000;
            description = "Milliseconds to wait after niri is ready before the service starts processing events.";
          };
          soloWindowBehavior = lib.mkOption {
            type = lib.types.enum [
              "nothing"
              "maximize"
              "resize"
            ];
            default = "resize";
            description = "What to do when a workspace has exactly one tiling window.";
          };
          soloWindowWidth = lib.mkOption {
            type = lib.types.str;
            default = "50%";
            description = "Column width applied to the solo window when soloWindowBehavior is resize.";
          };
          soloWindowHeight = lib.mkOption {
            type = lib.types.str;
            default = "100%";
            description = "Window height applied to the solo window when soloWindowBehavior is resize.";
          };
          resetKeybind = lib.mkOption {
            type = lib.types.str;
            default = "Mod+Shift+R";
            description = "Keybind that re-applies tiling to all windows on the focused workspace.";
          };
          floatingCarryOver = lib.mkOption {
            type = lib.types.submodule {
              options = {
                enable = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                  description = "Move floating windows to the newly activated workspace on workspace switches.";
                };
                excludedWorkspaces = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [ "scratch" ];
                  description = "Workspace names that block carry-over when they are the source or target.";
                };
              };
            };
            default = { };
            description = "Carry-over behavior for floating windows on workspace switches.";
          };
        };
      };
      default = { };
      description = "Automatically stack newly opened tiled windows into columns.";
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
      default = false;
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
    blurAppIds = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "App IDs for which to enable blur with xray via window rules.";
    };
    blurAppIdsNoXray = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "App IDs for which to enable blur without xray via window rules.";
    };
  };

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
    enabled = config: {
      nx.linux.desktop.niri.autoTiler.ignoredAppIds = [ "org.nx.scratchpad" ];
      nx.linux.desktop.niri.blurAppIdsNoXray = [ "org.nx.scratchpad" ];
    };

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
        autoTilerConfig = (self.options config).autoTiler;
        hasAutoTiler = autoTilerConfig.enable;

        lateRuleAppIds = lib.unique (
          lib.filter (id: id != null) (
            map (rule: rule.match."app-id") (
              lib.filter (
                rule: rule.match."app-id" != null && (rule.apply.float == true || rule.apply.workspace != null)
              ) lateRules
            )
          )
        );
        autoTilerEffectiveConfig = autoTilerConfig // {
          ignoredAppIds = lib.unique (autoTilerConfig.ignoredAppIds ++ lateRuleAppIds);
        };

        lateRulesJson = pkgs.writeText "niri-late-rules.json" (builtins.toJSON lateRules);
        autoTilerJson = pkgs.writeText "niri-auto-tiler.json" (builtins.toJSON autoTilerEffectiveConfig);

        autoTilerCmdScript =
          pkgs.writers.writePython3 "niri-auto-tiler-cmd"
            {
              flakeIgnore = [ "E501" ];
            }
            ''
              import os
              import socket
              import sys


              def main():
                  if len(sys.argv) < 2:
                      print("Usage: niri-auto-tiler-cmd <command>", file=sys.stderr)
                      sys.exit(1)
                  sock_path = os.path.join(
                      os.environ.get("XDG_RUNTIME_DIR", ""),
                      "niri-auto-tiler.sock",
                  )
                  try:
                      with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                          s.connect(sock_path)
                          s.sendall((sys.argv[1] + "\n").encode())
                  except Exception as e:
                      print(f"error: {e}", file=sys.stderr)
                      sys.exit(1)


              if __name__ == "__main__":
                  main()
            '';

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


              def niri_json(*args):
                  result = subprocess.run(
                      [NIRI, "msg", "--json", *args],
                      capture_output=True, text=True,
                  )
                  if result.returncode != 0:
                      log.warning(
                          "failed to query niri json for %s: %s",
                          " ".join(args), result.stderr.strip(),
                      )
                      return None
                  try:
                      return json.loads(result.stdout)
                  except json.JSONDecodeError:
                      log.warning(
                          "failed to decode niri json for %s",
                          " ".join(args),
                      )
                      return None


              def center_floating_window(wid, app_id, title):
                  windows = niri_json("windows")
                  if windows is None:
                      return

                  window = next((w for w in windows if w.get("id") == wid), None)
                  if window is None:
                      log.warning("window %d not found for centering", wid)
                      return
                  if not window.get("is_floating"):
                      log.info("window %d is not floating, skipping centering", wid)
                      return

                  layout = window.get("layout") or {}
                  size = layout.get("tile_size") or layout.get("window_size")
                  invalid_size = any([
                      size is None,
                      not isinstance(size, list),
                      len(size) < 2 if isinstance(size, list) else True,
                      size[0] is None if isinstance(size, list) and len(size) > 0 else True,
                      size[1] is None if isinstance(size, list) and len(size) > 1 else True,
                  ])
                  if invalid_size:
                      log.warning("window %d has no usable size, skipping centering", wid)
                      return

                  workspace_id = window.get("workspace_id")
                  if workspace_id is None:
                      log.warning(
                          "window %d has no workspace id, skipping centering", wid,
                      )
                      return

                  workspaces = niri_json("workspaces")
                  if workspaces is None:
                      return
                  workspace = next(
                      (ws for ws in workspaces if ws.get("id") == workspace_id),
                      None,
                  )
                  if workspace is None:
                      log.warning(
                          "workspace %s not found for window %d, skipping centering",
                          workspace_id, wid,
                      )
                      return

                  output_name = workspace.get("output")
                  if not output_name:
                      log.warning(
                          "workspace %s has no output, skipping centering",
                          workspace_id,
                      )
                      return

                  outputs = niri_json("outputs")
                  if outputs is None:
                      return
                  output = outputs.get(output_name)
                  logical = (output or {}).get("logical") or {}
                  output_width = logical.get("width")
                  output_height = logical.get("height")
                  if output_width is None or output_height is None:
                      log.warning(
                          "output %s has no logical size, skipping centering",
                          output_name,
                      )
                      return

                  x = max(0, round((output_width - size[0]) / 2))
                  anchor_to_top = size[1] >= (output_height * 0.8)
                  if anchor_to_top:
                      y = 0
                  else:
                      y = max(0, round((output_height - size[1]) / 2))
                  niri_action(
                      app_id, title,
                      "move-floating-window",
                      "--id", str(wid),
                      "-x", str(x),
                      "-y", str(y),
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
                  if a.get("float") is True:
                      center_floating_window(wid, app_id, title)
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

        autoTilerScript =
          pkgs.writers.writePython3 "niri-auto-tiler"
            {
              flakeIgnore = [ "E501" ];
            }
            ''
              import json
              import logging
              import os
              import queue
              import socket
              import subprocess
              import sys
              import threading
              import time

              NIRI = "${pkgs.niri}/bin/niri"
              logging.basicConfig(
                  level=logging.INFO,
                  format="%(asctime)s %(levelname)s %(message)s",
                  datefmt="%H:%M:%S",
              )
              log = logging.getLogger("niri-auto-tiler")


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


              def load_config():
                  with open("${autoTilerJson}") as f:
                      return json.load(f)


              def niri_action(*args):
                  cmd = [NIRI, "msg", "action", *args]
                  log.info("niri cmd: %s", " ".join(args))
                  result = subprocess.run(cmd, capture_output=True, text=True)
                  if result.returncode != 0:
                      log.warning("niri cmd failed: %s", result.stderr.strip())
                      return False
                  return True


              def normalize_window(window):
                  data = dict(window)
                  data["layout"] = dict(window.get("layout") or {})
                  return data


              def workspace_name(workspaces_by_id, workspace_id):
                  workspace = workspaces_by_id.get(workspace_id) or {}
                  return workspace.get("name")


              def is_ignored_workspace(config, workspaces_by_id, workspace_id):
                  name = workspace_name(workspaces_by_id, workspace_id)
                  return name in config["ignoredWorkspaces"]


              def layout_position(window):
                  layout = window.get("layout") or {}
                  pos = layout.get("pos_in_scrolling_layout")
                  valid_pos = all([
                      isinstance(pos, list),
                      len(pos) >= 2 if isinstance(pos, list) else False,
                      pos[0] is not None if isinstance(pos, list) and len(pos) > 0 else False,
                      pos[1] is not None if isinstance(pos, list) and len(pos) > 1 else False,
                  ])
                  if not valid_pos:
                      return None
                  return (pos[0], pos[1])


              def is_fullscreen_window(window):
                  layout = window.get("layout") or {}
                  offset = layout.get("window_offset_in_tile")
                  return offset is not None and offset[0] == 0 and offset[1] == 0


              def is_tiling_candidate(config, workspaces_by_id, window):
                  if window is None:
                      return False
                  if window.get("is_floating"):
                      return False
                  if is_fullscreen_window(window):
                      return False
                  workspace_id = window.get("workspace_id")
                  if workspace_id is None:
                      return False
                  if is_ignored_workspace(config, workspaces_by_id, workspace_id):
                      return False
                  if window.get("app_id") in config["ignoredAppIds"]:
                      return False
                  return layout_position(window) is not None


              def physical_columns_for_workspace(windows_by_id, workspace_id):
                  cols = set()
                  for window in windows_by_id.values():
                      if window.get("workspace_id") != workspace_id:
                          continue
                      pos = layout_position(window)
                      if pos is not None:
                          cols.add(pos[0])
                  return cols


              def tiling_windows_for_workspace(config, workspaces_by_id, windows_by_id, workspace_id):
                  windows = []
                  for window in windows_by_id.values():
                      if window.get("workspace_id") != workspace_id:
                          continue
                      if not is_tiling_candidate(config, workspaces_by_id, window):
                          continue
                      windows.append(window)
                  windows.sort(
                      key=lambda w: (
                          layout_position(w)[0],
                          layout_position(w)[1],
                          w["id"],
                      ),
                  )
                  return windows


              def columns_for_windows(windows):
                  columns = {}
                  for window in windows:
                      col_idx, _row_idx = layout_position(window)
                      columns.setdefault(col_idx, []).append(window["id"])
                  return columns


              def can_stack_into_column(config, columns, target_col, neighbor_col):
                  target_ids = columns.get(target_col) or []
                  neighbor_ids = columns.get(neighbor_col) or []
                  if len(target_ids) != 1:
                      return False
                  if len(neighbor_ids) == 0:
                      return False
                  if len(target_ids) + len(neighbor_ids) > config["windowsPerColumn"]:
                      return False
                  return True


              def should_skip_due_to_first_column(config, sorted_cols, neighbor_col):
                  if config["firstColumnStacks"]:
                      return False
                  if len(sorted_cols) <= 2:
                      return True
                  return neighbor_col == sorted_cols[0]


              def with_focus(wid, fn):
                  result = subprocess.run(
                      [NIRI, "msg", "--json", "focused-window"],
                      capture_output=True, text=True,
                  )
                  focused_id = None
                  if result.returncode == 0:
                      try:
                          data = json.loads(result.stdout)
                          if data:
                              focused_id = data.get("id")
                      except json.JSONDecodeError:
                          pass
                  needs_restore = focused_id is not None and focused_id != wid
                  if needs_restore:
                      niri_action("focus-window", "--id", str(wid))
                  fn()
                  if needs_restore:
                      niri_action("focus-window", "--id", str(focused_id))


              def apply_solo_behavior(config, wid, app_id):
                  behavior = config["soloWindowBehavior"]
                  if behavior == "nothing":
                      return
                  log.info(
                      "applying solo behavior '%s' to window %d (app-id=%s)",
                      behavior, wid, app_id,
                  )
                  if behavior == "maximize":
                      with_focus(wid, lambda: niri_action("maximize-column"))
                  elif behavior == "resize":
                      def do_resize():
                          niri_action("set-column-width", config["soloWindowWidth"])
                          niri_action("set-window-height", config["soloWindowHeight"])
                      with_focus(wid, do_resize)


              def undo_solo_maximize(solo_maximized, workspace_id, windows_by_id):
                  for solo_wid in list(solo_maximized):
                      window = windows_by_id.get(solo_wid)
                      if window and window.get("workspace_id") == workspace_id:
                          log.info(
                              "un-maximizing previous solo window %d (app-id=%s)",
                              solo_wid, window.get("app_id", ""),
                          )
                          with_focus(solo_wid, lambda: niri_action("maximize-column"))
                          solo_maximized.discard(solo_wid)


              def undo_solo_resize(solo_resized, workspace_id, windows_by_id):
                  for solo_wid in list(solo_resized):
                      window = windows_by_id.get(solo_wid)
                      if window and window.get("workspace_id") == workspace_id:
                          orig_col_px = solo_resized[solo_wid]
                          log.info(
                              "un-resizing previous solo window %d (app-id=%s)",
                              solo_wid, window.get("app_id", ""),
                          )

                          def do_undo(w=orig_col_px):
                              if w is not None:
                                  niri_action("set-column-width", str(w))
                              niri_action("reset-window-height")

                          with_focus(solo_wid, do_undo)
                          solo_resized.pop(solo_wid, None)


              def process_window(
                  config,
                  workspaces_by_id,
                  windows_by_id,
                  handled,
                  pending,
                  deferred_once,
                  solo_maximized,
                  solo_resized,
                  wid,
              ):
                  window = windows_by_id.get(wid)
                  app_id = (window or {}).get("app_id", "")
                  if window is None or layout_position(window) is None:
                      return False
                  if not is_tiling_candidate(config, workspaces_by_id, window):
                      log.info(
                          "skipping window %d (app-id=%s), not an eligible tiling candidate",
                          wid, app_id,
                      )
                      handled.add(wid)
                      pending.discard(wid)
                      return True

                  workspace_id = window.get("workspace_id")
                  workspace_windows = tiling_windows_for_workspace(
                      config, workspaces_by_id, windows_by_id, workspace_id,
                  )
                  if not any(w["id"] == wid for w in workspace_windows):
                      log.info(
                          "skipping window %d (app-id=%s), missing from workspace %s tiling set",
                          wid, app_id, workspace_id,
                      )
                      return False

                  columns = columns_for_windows(workspace_windows)
                  sorted_cols = sorted(columns.keys())
                  column_count = len(sorted_cols)
                  log.info(
                      "processing window %d (app-id=%s) on workspace %s with %d tiling window(s) across %d column(s)",
                      wid, app_id, workspace_id, len(workspace_windows), column_count,
                  )

                  if config["columnLimit"] > 0 and column_count > config["columnLimit"]:
                      log.info(
                          "marking window %d (app-id=%s) handled, column limit %d exceeded",
                          wid, app_id, config["columnLimit"],
                      )
                      handled.add(wid)
                      pending.discard(wid)
                      return True

                  if len(workspace_windows) <= 1:
                      log.info(
                          "marking window %d (app-id=%s) handled as solo window on workspace %s",
                          wid, app_id, workspace_id,
                      )
                      handled.add(wid)
                      pending.discard(wid)
                      if config["soloWindowBehavior"] == "resize":
                          _layout = (windows_by_id.get(wid) or {}).get("layout") or {}
                          _ws = _layout.get("window_size")
                          _orig_col_px = int(_ws[0]) if _ws else None
                      apply_solo_behavior(config, wid, app_id)
                      if config["soloWindowBehavior"] == "maximize":
                          solo_maximized.add(wid)
                      elif config["soloWindowBehavior"] == "resize":
                          solo_resized[wid] = _orig_col_px
                      return True

                  if len(workspace_windows) == 2 and config["soloWindowBehavior"] == "maximize":
                      undo_solo_maximize(solo_maximized, workspace_id, windows_by_id)
                  elif len(workspace_windows) == 2 and config["soloWindowBehavior"] == "resize":
                      undo_solo_resize(solo_resized, workspace_id, windows_by_id)

                  new_col, _new_row = layout_position(window)
                  if len(columns.get(new_col) or []) != 1:
                      if wid not in deferred_once:
                          deferred_once.add(wid)
                          log.info(
                              "deferring window %d (app-id=%s), column %s has %d windows, waiting for layout to settle",
                              wid, app_id, new_col, len(columns.get(new_col) or []),
                          )
                          return False
                      deferred_once.discard(wid)
                      log.info(
                          "marking window %d (app-id=%s) handled, column %s already has %d window(s)",
                          wid, app_id, new_col, len(columns.get(new_col) or []),
                      )
                      handled.add(wid)
                      pending.discard(wid)
                      return True

                  if len(workspace_windows) == 2 and not config["firstColumnStacks"]:
                      log.info(
                          "marking window %d (app-id=%s) handled, firstColumnStacks is disabled for a two-window workspace",
                          wid, app_id,
                      )
                      handled.add(wid)
                      pending.discard(wid)
                      return True

                  left_cols = [col for col in sorted_cols if col < new_col]
                  right_cols = [col for col in sorted_cols if col > new_col]
                  candidate_cols = []
                  if left_cols:
                      candidate_cols.append(left_cols[-1])
                  if right_cols:
                      candidate_cols.append(right_cols[0])

                  physical_cols = physical_columns_for_workspace(windows_by_id, workspace_id)

                  for neighbor_col in candidate_cols:
                      lo, hi = min(new_col, neighbor_col), max(new_col, neighbor_col)
                      if any(lo < c < hi for c in physical_cols):
                          log.info(
                              "skipping neighbor column %s for window %d (app-id=%s), non-tiling column between %s and %s",
                              neighbor_col, wid, app_id, new_col, neighbor_col,
                          )
                          continue
                      if should_skip_due_to_first_column(
                          config, sorted_cols, neighbor_col,
                      ):
                          log.info(
                              "skipping neighbor column %s for window %d (app-id=%s), first column stacking disabled",
                              neighbor_col, wid, app_id,
                          )
                          continue
                      if not can_stack_into_column(
                          config, columns, new_col, neighbor_col,
                      ):
                          log.info(
                              "skipping neighbor column %s for window %d (app-id=%s), target column %s has %d window(s) and neighbor has %d",
                              neighbor_col,
                              wid,
                              app_id,
                              new_col,
                              len(columns.get(new_col) or []),
                              len(columns.get(neighbor_col) or []),
                          )
                          continue
                      log.info(
                          "stacking window %d (app-id=%s), merging neighbor column %s into new column %s",
                          wid, app_id, neighbor_col, new_col,
                      )
                      if neighbor_col < new_col:
                          niri_action(
                              "consume-or-expel-window-left",
                              "--id", str(wid),
                          )
                      else:
                          niri_action(
                              "consume-or-expel-window-right",
                              "--id", str(wid),
                          )
                      merged_wids = columns.get(neighbor_col) or []
                      combined_wids = [wid] + merged_wids
                      equal_pct = f"{int(100 / len(combined_wids))}%"
                      for w in combined_wids:
                          niri_action("set-window-height", "--id", str(w), equal_pct)
                      new_layout = dict(windows_by_id[wid].get("layout") or {})
                      for merged_wid in merged_wids:
                          if merged_wid in windows_by_id:
                              windows_by_id[merged_wid]["layout"] = new_layout
                      for w in combined_wids:
                          handled.add(w)
                          pending.discard(w)
                      return "acted"

                  my_wids = columns.get(new_col) or []
                  min_cols = -(-len(workspace_windows) // config["windowsPerColumn"])
                  if len(my_wids) == 1 and 2 <= config["windowsPerColumn"] and len(sorted_cols) > min_cols:
                      for neighbor_col in candidate_cols:
                          neighbor_wids = columns.get(neighbor_col) or []
                          if len(neighbor_wids) <= 1:
                              continue
                          lo, hi = min(new_col, neighbor_col), max(new_col, neighbor_col)
                          if any(lo < c < hi for c in physical_cols):
                              continue
                          if should_skip_due_to_first_column(config, sorted_cols, neighbor_col):
                              continue
                          pull_wid = min(
                              neighbor_wids,
                              key=lambda w_id: (layout_position(windows_by_id.get(w_id) or {}) or (0, 0))[1],
                          )
                          pull_cmd = (
                              "consume-or-expel-window-left"
                              if neighbor_col > new_col
                              else "consume-or-expel-window-right"
                          )
                          log.info(
                              "pulling window %d from over-full column %s into column %s for window %d (app-id=%s)",
                              pull_wid, neighbor_col, new_col, wid, app_id,
                          )
                          niri_action(pull_cmd, "--id", str(pull_wid))
                          niri_action(pull_cmd, "--id", str(pull_wid))
                          for w in [wid, pull_wid]:
                              niri_action("set-window-height", "--id", str(w), "50%")
                          remaining = [w_id for w_id in neighbor_wids if w_id != pull_wid]
                          if remaining:
                              rem_pct = f"{int(100 / len(remaining))}%"
                              for w_id in remaining:
                                  niri_action("set-window-height", "--id", str(w_id), rem_pct)
                          windows_by_id[pull_wid]["layout"] = dict(windows_by_id[wid].get("layout") or {})
                          for w_id in [wid, pull_wid] + remaining:
                              handled.add(w_id)
                              pending.discard(w_id)
                          return "acted"

                  log.info(
                      "marking window %d (app-id=%s) handled, no eligible neighboring column found",
                      wid, app_id,
                  )
                  if len(my_wids) == 1:
                      niri_action("set-window-height", "--id", str(wid), "100%")
                  handled.add(wid)
                  pending.discard(wid)
                  return True


              def process_pending(config, workspaces_by_id, windows_by_id, handled, pending, deferred_once, solo_maximized, solo_resized):
                  for wid in list(sorted(pending)):
                      if wid in handled:
                          pending.discard(wid)
                          continue
                      result = process_window(
                          config, workspaces_by_id, windows_by_id,
                          handled, pending, deferred_once, solo_maximized, solo_resized, wid,
                      )
                      if result == "acted":
                          return "acted"
                  return True


              def handle_reset(config, workspaces_by_id, windows_by_id, handled, pending, deferred_once, solo_maximized, solo_resized):
                  w_result = subprocess.run(
                      [NIRI, "msg", "--json", "windows"],
                      capture_output=True, text=True,
                  )
                  if w_result.returncode == 0:
                      try:
                          for window in json.loads(w_result.stdout):
                              wid = window["id"]
                              if wid in windows_by_id:
                                  windows_by_id[wid] = normalize_window(window)
                      except (json.JSONDecodeError, KeyError, TypeError):
                          pass
                  result = subprocess.run(
                      [NIRI, "msg", "--json", "focused-window"],
                      capture_output=True, text=True,
                  )
                  if result.returncode != 0:
                      log.warning("reset: could not get focused window")
                      return
                  try:
                      focused = json.loads(result.stdout)
                  except json.JSONDecodeError:
                      log.warning("reset: could not parse focused window")
                      return
                  if not focused:
                      log.info("reset: no focused window, nothing to do")
                      return
                  focused_workspace_id = focused.get("workspace_id")
                  target_windows = tiling_windows_for_workspace(
                      config, workspaces_by_id, windows_by_id, focused_workspace_id,
                  )
                  log.info(
                      "resetting workspace %s with %d tiling window(s)",
                      focused_workspace_id, len(target_windows),
                  )
                  for w in target_windows:
                      wid = w["id"]
                      handled.discard(wid)
                      deferred_once.discard(wid)
                      solo_maximized.discard(wid)
                      solo_resized.pop(wid, None)
                      pending.add(wid)


              def carry_over_floating(source_ws_id, target_ws_id, config, workspaces_by_id, windows_by_id):
                  cfg = config.get("floatingCarryOver", {})
                  if not cfg.get("enable", False):
                      return
                  excluded = cfg.get("excludedWorkspaces", [])
                  source_ws = workspaces_by_id.get(source_ws_id) or {}
                  target_ws = workspaces_by_id.get(target_ws_id) or {}
                  source_name = source_ws.get("name") or ""
                  target_name = target_ws.get("name") or ""
                  if source_name in excluded or target_name in excluded:
                      return
                  floating = [
                      w for w in windows_by_id.values()
                      if w.get("workspace_id") == source_ws_id and w.get("is_floating", False)
                  ]
                  if not floating:
                      return
                  target_ref = target_name or str(target_ws.get("idx", target_ws_id))
                  for window in floating:
                      wid = window["id"]
                      log.info(
                          "carrying over floating window %d (app-id=%s) from workspace %s to %s",
                          wid, window.get("app_id", ""), source_name, target_name,
                      )
                      niri_action(
                          "move-window-to-workspace",
                          "--window-id", str(wid),
                          "--focus", "false",
                          target_ref,
                      )


              def socket_listener(sock_path, cmd_queue):
                  try:
                      os.unlink(sock_path)
                  except FileNotFoundError:
                      pass
                  server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                  server.bind(sock_path)
                  server.listen(5)
                  log.info("socket listener started at %s", sock_path)
                  while True:
                      conn, _ = server.accept()
                      with conn:
                          data = conn.recv(1024).decode().strip()
                          if data:
                              log.info("received socket command: %s", data)
                              cmd_queue.put(data)


              def main():
                  config = load_config()
                  log.info("starting auto tiler")

                  if not wait_for_niri():
                      log.error("niri not ready after 30s, exiting")
                      sys.exit(1)

                  startup_delay = max(0, config["startupDelayMs"]) / 1000.0
                  if startup_delay > 0:
                      time.sleep(startup_delay)

                  sock_path = os.path.join(
                      os.environ.get("XDG_RUNTIME_DIR", ""),
                      "niri-auto-tiler.sock",
                  )
                  cmd_queue = queue.Queue()
                  t = threading.Thread(
                      target=socket_listener, args=(sock_path, cmd_queue), daemon=True,
                  )
                  t.start()

                  windows_by_id = {}
                  workspaces_by_id = {}
                  active_workspace_per_output = {}
                  handled = set()
                  pending = set()
                  deferred_once = set()
                  solo_maximized = set()
                  solo_resized = {}
                  saw_workspaces = False
                  saw_windows = False
                  bootstrapped = False

                  proc = subprocess.Popen(
                      [NIRI, "msg", "--json", "event-stream"],
                      stdout=subprocess.PIPE,
                      text=True,
                  )

                  event_queue = queue.Queue()

                  def _read_events(proc, event_queue):
                      for line in proc.stdout:
                          event_queue.put(line)
                      event_queue.put(None)

                  threading.Thread(
                      target=_read_events, args=(proc, event_queue), daemon=True,
                  ).start()

                  while True:
                      try:
                          line = event_queue.get(timeout=0.1)
                      except queue.Empty:
                          if bootstrapped:
                              had_reset = not cmd_queue.empty()
                              while not cmd_queue.empty():
                                  cmd_queue.get_nowait()
                                  handle_reset(
                                      config, workspaces_by_id, windows_by_id,
                                      handled, pending, deferred_once, solo_maximized, solo_resized,
                                  )
                              if had_reset:
                                  process_pending(
                                      config, workspaces_by_id, windows_by_id,
                                      handled, pending, deferred_once, solo_maximized, solo_resized,
                                  )
                          continue
                      if line is None:
                          break

                      try:
                          event = json.loads(line)
                      except json.JSONDecodeError:
                          continue

                      if "WorkspacesChanged" in event:
                          saw_workspaces = True
                          workspaces = event["WorkspacesChanged"]["workspaces"]
                          if not bootstrapped:
                              for ws in workspaces:
                                  if ws.get("is_active") and ws.get("output"):
                                      active_workspace_per_output[ws["output"]] = ws["id"]
                          workspaces_by_id = {
                              workspace["id"]: workspace
                              for workspace in workspaces
                          }

                      elif "WorkspaceActivated" in event:
                          activated = event["WorkspaceActivated"]
                          new_ws_id = activated["id"]
                          if activated.get("focused", False):
                              new_ws = workspaces_by_id.get(new_ws_id) or {}
                              output = new_ws.get("output")
                              if output:
                                  old_ws_id = active_workspace_per_output.get(output)
                                  if bootstrapped and old_ws_id is not None and old_ws_id != new_ws_id:
                                      carry_over_floating(
                                          old_ws_id, new_ws_id,
                                          config, workspaces_by_id, windows_by_id,
                                      )
                                  active_workspace_per_output[output] = new_ws_id

                      elif "WindowsChanged" in event:
                          saw_windows = True
                          windows = event["WindowsChanged"]["windows"]
                          windows_by_id = {
                              window["id"]: normalize_window(window)
                              for window in windows
                          }

                      elif "WindowOpenedOrChanged" in event:
                          window = normalize_window(
                              event["WindowOpenedOrChanged"]["window"],
                          )
                          wid = window["id"]
                          app_id = window.get("app_id", "")
                          previous = windows_by_id.get(wid)
                          windows_by_id[wid] = window
                          if bootstrapped:
                              if previous is None:
                                  log.info(
                                      "queued new window %d (app-id=%s) for auto tiling",
                                      wid, app_id,
                                  )
                                  pending.add(wid)
                              elif config["applyOnMove"] and previous.get("workspace_id") != window.get("workspace_id"):
                                  log.info(
                                      "re-queued moved window %d (app-id=%s) from workspace %s to %s",
                                      wid,
                                      app_id,
                                      previous.get("workspace_id"),
                                      window.get("workspace_id"),
                                  )
                                  handled.discard(wid)
                                  pending.add(wid)
                              elif not previous.get("is_floating") and window.get("is_floating"):
                                  handled.discard(wid)
                                  ws_id = window.get("workspace_id")
                                  if ws_id is not None and config["soloWindowBehavior"] != "nothing" and is_tiling_candidate(config, workspaces_by_id, previous):
                                      remaining = tiling_windows_for_workspace(
                                          config, workspaces_by_id, windows_by_id, ws_id,
                                      )
                                      if len(remaining) == 1:
                                          solo_wid = remaining[0]["id"]
                                          solo_app_id = remaining[0].get("app_id", "")
                                          log.info(
                                              "applying solo behavior to window %d (app-id=%s) after window %d floated",
                                              solo_wid, solo_app_id, wid,
                                          )
                                          if config["soloWindowBehavior"] == "resize":
                                              _layout = (windows_by_id.get(solo_wid) or {}).get("layout") or {}
                                              _ws = _layout.get("window_size")
                                              _orig_col_px = int(_ws[0]) if _ws else None
                                          apply_solo_behavior(config, solo_wid, solo_app_id)
                                          handled.discard(solo_wid)
                                          if config["soloWindowBehavior"] == "maximize":
                                              solo_maximized.add(solo_wid)
                                          elif config["soloWindowBehavior"] == "resize":
                                              solo_resized[solo_wid] = _orig_col_px
                              elif previous.get("is_floating") and not window.get("is_floating"):
                                  log.info(
                                      "re-queued window %d (app-id=%s) as it became tiling",
                                      wid, app_id,
                                  )
                                  handled.discard(wid)
                                  pending.add(wid)

                      elif "WindowLayoutsChanged" in event:
                          changes = event["WindowLayoutsChanged"]["changes"]
                          old_positions = {
                              wid: layout_position(windows_by_id[wid])
                              for wid, _layout in changes
                              if wid in windows_by_id
                          }
                          for wid, layout in changes:
                              if wid in windows_by_id and layout:
                                  windows_by_id[wid]["layout"].update(layout)
                          if bootstrapped:
                              for wid, _layout in changes:
                                  if wid not in windows_by_id:
                                      continue
                                  w = windows_by_id[wid]
                                  if not is_tiling_candidate(config, workspaces_by_id, w):
                                      continue
                                  old_pos = old_positions.get(wid)
                                  new_pos = layout_position(w)
                                  if old_pos is None or new_pos is None or old_pos[0] == new_pos[0]:
                                      continue
                                  old_col = old_pos[0]
                                  new_col = new_pos[0]
                                  ws_id = w.get("workspace_id")
                                  if ws_id is None:
                                      continue
                                  old_col_remaining = [ow for ow in windows_by_id.values() if ow.get("workspace_id") == ws_id and is_tiling_candidate(config, workspaces_by_id, ow) and (layout_position(ow) or (None, None))[0] == old_col]
                                  if len(old_col_remaining) == 1:
                                      lone = old_col_remaining[0]
                                      log.info(
                                          "resetting height of window %d (app-id=%s) left alone after window %d moved column",
                                          lone["id"], lone.get("app_id", ""), wid,
                                      )
                                      niri_action("reset-window-height", "--id", str(lone["id"]))
                                  new_col_occupants = [ow for ow in windows_by_id.values() if ow.get("workspace_id") == ws_id and is_tiling_candidate(config, workspaces_by_id, ow) and (layout_position(ow) or (None, None))[0] == new_col]
                                  if len(new_col_occupants) == 1:
                                      log.info(
                                          "resetting height of window %d (app-id=%s) displaced to solo column",
                                          wid, w.get("app_id", ""),
                                      )
                                      niri_action("reset-window-height", "--id", str(wid))

                      elif "WindowClosed" in event:
                          wid = event["WindowClosed"]["id"]
                          closing_window = windows_by_id.pop(wid, None)
                          handled.discard(wid)
                          pending.discard(wid)
                          deferred_once.discard(wid)
                          solo_maximized.discard(wid)
                          solo_resized.pop(wid, None)
                          if bootstrapped and closing_window is not None and is_tiling_candidate(config, workspaces_by_id, closing_window):
                              closing_workspace_id = closing_window.get("workspace_id")
                              if closing_workspace_id is not None:
                                  closing_col = layout_position(closing_window)
                                  if closing_col is not None:
                                      closing_col_idx = closing_col[0]
                                      for w in list(windows_by_id.values()):
                                          if w.get("workspace_id") == closing_workspace_id and is_tiling_candidate(config, workspaces_by_id, w):
                                              w_pos = layout_position(w)
                                              if w_pos is not None and w_pos[0] == closing_col_idx:
                                                  w_id = w["id"]
                                                  log.info(
                                                      "re-queued column-mate window %d (app-id=%s) after window %d closed",
                                                      w_id, w.get("app_id", ""), wid,
                                                  )
                                                  handled.discard(w_id)
                                                  deferred_once.discard(w_id)
                                                  pending.add(w_id)
                                  if config["soloWindowBehavior"] != "nothing":
                                      remaining = tiling_windows_for_workspace(
                                          config, workspaces_by_id, windows_by_id, closing_workspace_id,
                                      )
                                      if len(remaining) == 1:
                                          solo_wid = remaining[0]["id"]
                                          solo_app_id = remaining[0].get("app_id", "")
                                          log.info(
                                              "applying solo behavior to remaining window %d (app-id=%s) after close",
                                              solo_wid, solo_app_id,
                                          )
                                          if config["soloWindowBehavior"] == "resize":
                                              _layout = (windows_by_id.get(solo_wid) or {}).get("layout") or {}
                                              _ws = _layout.get("window_size")
                                              _orig_col_px = int(_ws[0]) if _ws else None
                                          apply_solo_behavior(config, solo_wid, solo_app_id)
                                          if config["soloWindowBehavior"] == "maximize":
                                              solo_maximized.add(solo_wid)
                                          elif config["soloWindowBehavior"] == "resize":
                                              solo_resized[solo_wid] = _orig_col_px
                                          handled.add(solo_wid)
                                          pending.discard(solo_wid)

                      if not bootstrapped and saw_workspaces and saw_windows:
                          handled = set(windows_by_id.keys())
                          pending.clear()
                          bootstrapped = True
                          log.info(
                              "bootstrapped with %d existing window(s)",
                              len(handled),
                          )
                          continue

                      if bootstrapped:
                          while not cmd_queue.empty():
                              cmd_queue.get_nowait()
                              handle_reset(
                                  config, workspaces_by_id, windows_by_id,
                                  handled, pending, deferred_once, solo_maximized, solo_resized,
                              )
                          process_pending(
                              config, workspaces_by_id, windows_by_id,
                              handled, pending, deferred_once, solo_maximized, solo_resized,
                          )

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

        blurCfg = {
          passes = 2;
          offset = "3.0";
          noise = "0.02";
          saturation = "1.5";
        };

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

        home.file."${defs.binDir}/niri-scratchpad" = {
          source = self.file "niri-scratchpad/niri-scratchpad.sh";
          executable = true;
        };

        home.file."${defs.binDir}/restart-niri" = lib.mkIf (self.options config).addRestartShortcut {
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

        home.file."${defs.binDir}/power-menu" = {
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

        home.file."${defs.binDir}/scratchpad-terminal" =
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

        home.file."${defs.binDir}/niri-workspace-action" = {
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

        home.file."${defs.binDir}/nop" = {
          executable = true;
          text = ''
            #!/usr/bin/env bash
            exit 0
          '';
        };

        home.file."${defs.binDir}/niri-auto-tiler-cmd" = lib.mkIf hasAutoTiler {
          executable = true;
          source = autoTilerCmdScript;
        };

        systemd.user.services =
          (lib.optionalAttrs hasLateRules {
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
          })
          // (lib.optionalAttrs hasAutoTiler {
            "niri-auto-tiler" = {
              Unit = {
                Description = "Niri auto tiler";
                PartOf = [ "graphical-session.target" ];
                After = [ "graphical-session.target" ];
                StartLimitIntervalSec = 0;
              };
              Service = {
                ExecStart = "${autoTilerScript}";
                Restart = "always";
                RestartSec = "2s";
                Type = "simple";
              };
              Install = {
                WantedBy = [ "graphical-session.target" ];
              };
            };
          });

        programs.niri = {
          package = pkgs.niri;
          settings = {
            includes = [
              (toString (
                pkgs.writeText "niri-blur-global.kdl" ''
                  blur {
                      passes ${toString blurCfg.passes}
                      offset ${blurCfg.offset}
                      noise ${blurCfg.noise}
                      saturation ${blurCfg.saturation}
                  }
                ''
              ))
            ]
            ++ map (
              appId:
              toString (
                pkgs.writeText "niri-blur-${appId}.kdl" ''
                  window-rule {
                      match app-id="${appId}"
                      background-effect {
                          blur true
                          xray true
                          noise ${blurCfg.noise}
                          saturation ${blurCfg.saturation}
                      }
                  }
                ''
              )
            ) (self.options config).blurAppIds
            ++ map (
              appId:
              toString (
                pkgs.writeText "niri-blur-noxray-${appId}.kdl" ''
                  window-rule {
                      match app-id="${appId}"
                      background-effect {
                          blur true
                          xray false
                          noise ${blurCfg.noise}
                          saturation ${blurCfg.saturation}
                      }
                  }
                ''
              )
            ) (self.options config).blurAppIdsNoXray
            ++ [
              (toString (
                pkgs.writeText "niri-recent-windows.kdl" ''
                  recent-windows {
                      on
                      debounce-ms 750
                      open-delay-ms 150
                      highlight {
                          active-color "${activeColor}ff"
                          urgent-color "${theme.colors.semantic.warning.html}ff"
                          padding 30
                          corner-radius 0
                      }
                      previews {
                          max-height 480
                          max-scale 0.5
                      }
                      binds {
                          Mod+Shift+Space { next-window; }
                          Mod+Ctrl+Shift+Space { previous-window; }
                      }
                  }
                ''
              ))
            ];

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
                }
                // lib.optionalAttrs (secondaryDisplay != null) {
                  "Mod+Ctrl+Tab" = {
                    action = spawn-sh "niri-workspace-action --change-wallpaper move-column-to-monitor-next";
                    hotkey-overlay.title = "Monitor:Move column to next monitor";
                  };

                  "Mod+Shift+Tab" = {
                    action = spawn-sh "niri-workspace-action --change-wallpaper focus-monitor-next";
                    hotkey-overlay.title = "Monitor:Cycle monitor focus";
                  };
                }
                // lib.optionalAttrs hasAutoTiler {
                  ${autoTilerConfig.resetKeybind} = {
                    action = spawn-sh "niri-auto-tiler-cmd reset";
                    hotkey-overlay.title = "Tiling:Reset workspace tiling";
                  };
                };
              in
              (lib.filterAttrs (k: _: k != "Mod+Shift+Space" && k != "Mod+Ctrl+Shift+Space") nopBindings)
              // actualBindings;

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

        assertions = [
          {
            assertion =
              !(lib.hasAttrByPath [
                "Mod+Shift+Space"
                "hotkey-overlay"
                "title"
              ] config.programs.niri.settings.binds);
            message = "Mod+Shift+Space is reserved for the built-in window switcher. Remove the custom binding!";
          }
          {
            assertion =
              !(lib.hasAttrByPath [
                "Mod+Ctrl+Shift+Space"
                "hotkey-overlay"
                "title"
              ] config.programs.niri.settings.binds);
            message = "Mod+Ctrl+Shift+Space is reserved for the built-in window switcher. Remove the custom binding!";
          }
        ];
      };

    ifEnabled.linux.desktop-modules.nwg-wrapper = {
      enabled = config: {
        nx.linux.desktop-modules.nwg-wrapper.extraKeybindings = [
          {
            key = "Mod+Shift+Space";
            title = "Apps:Window switcher next";
          }
          {
            key = "Mod+Ctrl+Shift+Space";
            title = "Apps:Window switcher prev";
          }
        ];
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
