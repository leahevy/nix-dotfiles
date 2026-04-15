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
let
  colorType = lib.types.submodule {
    options = {
      html = lib.mkOption {
        type = lib.types.str;
        description = "HTML hex color code";
      };
      name = lib.mkOption {
        type = lib.types.str;
        description = "ANSI color name";
      };
      term = lib.mkOption {
        type = lib.types.int;
        description = "256-color terminal code";
      };
    };
  };

  nullableColorType = lib.types.nullOr colorType;

  colorSetType = lib.types.attrsOf colorType;

  commandFnType = lib.types.functionTo (lib.types.listOf lib.types.str);
  commandFn2Type = lib.types.functionTo commandFnType;

  programType = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Program name";
      };
      package = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        description = "Program package";
      };
      openCommand = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Command to open the program (as list of args)";
      };
      openFileCommand = lib.mkOption {
        type = lib.types.nullOr commandFnType;
        default = null;
        description = "Function: path -> [args] to open a file with the program";
      };
      additionalPackages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = "Additional packages required by this program";
      };
      desktopFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Desktop file name";
      };
      dirsToPersist = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Directories to persist for this program";
      };
      filesToPersist = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Files to persist for this program";
      };
      journalPatternsToIgnore = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [ ];
        description = "Journal watcher patterns to ignore for this program";
      };
      journalPatternsToHighlight = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [ ];
        description = "Journal watcher patterns to highlight for this program";
      };
      needsTerminal = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether this program needs to be run inside a terminal";
      };
      localBin = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether this programs absolute path resides in the user's .local/bin";
      };
      commandIsAbsolute = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether command paths are already absolute (e.g., macOS 'open' commands)";
      };
    };
  };

  terminalType = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "Terminal name";
      };
      package = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        description = "Terminal package";
      };
      openCommand = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Command to open the terminal (as list of args)";
      };
      openDirectoryCommand = lib.mkOption {
        type = lib.types.nullOr commandFnType;
        default = null;
        description = "Function: path -> [args] to open terminal in a directory";
      };
      openRunCommand = lib.mkOption {
        type = lib.types.nullOr commandFnType;
        default = null;
        description = "Function: cmd -> [args] to run a program in terminal";
      };
      openRunPrefix = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Command prefix for running programs (e.g., ['ghostty' '-e'])";
      };
      openShellCommand = lib.mkOption {
        type = lib.types.nullOr commandFnType;
        default = null;
        description = "Function: shellCmd -> [args] to run a shell command in terminal";
      };
      openWithClass = lib.mkOption {
        type = lib.types.nullOr commandFnType;
        default = null;
        description = "Function: class -> [args] to open terminal with a window class";
      };
      openRunWithClass = lib.mkOption {
        type = lib.types.nullOr commandFn2Type;
        default = null;
        description = "Function: class -> cmd -> [args] to run a program with a window class";
      };
      additionalPackages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = "Additional packages required by the terminal";
      };
      desktopFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Desktop file name";
      };
      dirsToPersist = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Directories to persist for this terminal";
      };
      filesToPersist = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Files to persist for this terminal";
      };
      journalPatternsToIgnore = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [ ];
        description = "Journal watcher patterns to ignore for this terminal";
      };
      journalPatternsToHighlight = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [ ];
        description = "Journal watcher patterns to highlight for this terminal";
      };
      localBin = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether this programs absolute path resides in the user's .local/bin";
      };
      commandIsAbsolute = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether command paths are already absolute (e.g., macOS 'open' commands)";
      };
    };
  };

  dmenuOptsFnType = lib.types.functionTo (lib.types.listOf lib.types.str);

  appLauncherType = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "App launcher name";
      };
      package = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        description = "App launcher package";
      };
      openCommand = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Command to open the launcher (as list of args)";
      };
      dmenuArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Args for simple dmenu mode (e.g., [\"-d\"] for fuzzel)";
      };
      dmenuCommand = lib.mkOption {
        type = lib.types.nullOr dmenuOptsFnType;
        default = null;
        description = "Function: {prompt, width, lines, placeholder} -> [args] for dmenu mode";
      };
      dmenuIndexCommand = lib.mkOption {
        type = lib.types.nullOr dmenuOptsFnType;
        default = null;
        description = "Function: {prompt, width, lines, placeholder} -> [args] for dmenu mode returning index";
      };
      additionalPackages = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = "Additional packages required by the launcher";
      };
      desktopFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Desktop file name";
      };
      journalPatternsToIgnore = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [ ];
        description = "Journal watcher patterns to ignore for this launcher";
      };
      journalPatternsToHighlight = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [ ];
        description = "Journal watcher patterns to highlight for this launcher";
      };
      localBin = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether this programs absolute path resides in the user's .local/bin";
      };
      commandIsAbsolute = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether command paths are already absolute (e.g., macOS 'open' commands)";
      };
    };
  };

  fontType = lib.types.submodule {
    options = {
      path = lib.mkOption {
        type = lib.types.str;
        description = "Font path in format: package/FontName";
      };
      useUnstable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether to use unstable package";
      };
    };
  };

  blockType = lib.types.submodule {
    options = {
      background = lib.mkOption {
        type = colorType;
        description = "Block background color";
      };
      foreground = lib.mkOption {
        type = colorType;
        description = "Block foreground color";
      };
    };
  };
in
{
  name = "preferences";

  group = "core";
  input = "build";

  rawOptions = {
    nx.lib.iconResolveScript = lib.mkOption {
      type = lib.types.package;
      description = "nx-resolve-icon script for resolving icon names to store paths at runtime";
    };

    nx.lib.icons = lib.mkOption {
      type = lib.types.listOf (lib.types.either lib.types.str (lib.types.listOf lib.types.str));
      default = [ ];
      description = "Icon names or patterns declared for runtime use via nx-resolve-icon. Each entry is either a single name or a list of names tried in order (first found wins).";
    };

    nx.lib.primaryIcons = lib.mkOption {
      type = lib.types.listOf (lib.types.either lib.types.str (lib.types.listOf lib.types.str));
      default = [ ];
      description = "Icon names validated against the primary icon theme only.";
    };

    nx.preferences = {
      theme = {
        name = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Active theme name";
        };

        variant = lib.mkOption {
          type = lib.types.nullOr (
            lib.types.enum [
              "dark"
              "light"
            ]
          );
          default = null;
          description = "Theme variant";
        };

        tint = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Theme tint color name";
        };

        fonts = lib.mkOption {
          type = lib.types.submodule {
            options = {
              serif = lib.mkOption {
                type = lib.types.nullOr fontType;
                default = null;
              };
              sansSerif = lib.mkOption {
                type = lib.types.nullOr fontType;
                default = null;
              };
              monospace = lib.mkOption {
                type = lib.types.nullOr fontType;
                default = null;
              };
              emoji = lib.mkOption {
                type = lib.types.nullOr fontType;
                default = null;
              };
            };
          };
          default = { };
          description = "Theme fonts";
        };

        icons = lib.mkOption {
          type = lib.types.submodule {
            options = {
              primary = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Primary icon theme (format: package/ThemeName)";
              };
              fallback = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Fallback icon theme";
              };
            };
          };
          default = { };
          description = "Icon theme settings";
        };

        cursor = lib.mkOption {
          type = lib.types.submodule {
            options = {
              style = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = "Cursor style (format: package/CursorName)";
              };
              size = lib.mkOption {
                type = lib.types.nullOr lib.types.int;
                default = null;
                description = "Cursor size";
              };
            };
          };
          default = { };
          description = "Cursor settings";
        };

        colors = lib.mkOption {
          type = lib.types.submodule {
            options = {
              main = lib.mkOption {
                type = lib.types.submodule {
                  options = {
                    backgrounds = lib.mkOption {
                      type = colorSetType;
                      default = { };
                      description = "Background colors (primary, secondary, tertiary, themed)";
                    };
                    foregrounds = lib.mkOption {
                      type = colorSetType;
                      default = { };
                      description = "Foreground colors (subtle, secondary, primary, emphasized, strong)";
                    };
                    base = lib.mkOption {
                      type = colorSetType;
                      default = { };
                      description = "Base colors (red, orange, yellow, green, cyan, blue, purple, pink)";
                    };
                  };
                };
                default = { };
                description = "Main desktop/GUI colors";
              };

              semantic = lib.mkOption {
                type = colorSetType;
                default = { };
                description = "Semantic colors (success, warning, error, info, hint, etc.)";
              };

              separators = lib.mkOption {
                type = colorSetType;
                default = { };
                description = "Separator colors (light, normal, dark, veryDark, ultraDark)";
              };

              blocks = lib.mkOption {
                type = lib.types.attrsOf blockType;
                default = { };
                description = "Block colors for powerline (primary, selection, accent, etc.)";
              };

              terminal = lib.mkOption {
                type = lib.types.submodule {
                  options = {
                    normalBackgrounds = lib.mkOption {
                      type = colorSetType;
                      default = { };
                      description = "Terminal background colors";
                    };
                    transparencyBackgrounds = lib.mkOption {
                      type = lib.types.attrsOf nullableColorType;
                      default = { };
                      description = "Terminal backgrounds with transparency support";
                    };
                    foregrounds = lib.mkOption {
                      type = colorSetType;
                      default = { };
                      description = "Terminal foreground colors";
                    };
                    colors = lib.mkOption {
                      type = colorSetType;
                      default = { };
                      description = "Terminal palette colors";
                    };
                  };
                };
                default = { };
                description = "Terminal-specific colors";
              };
            };
          };
          default = { };
          description = "Theme color definitions";
        };
      };

      desktop = {
        programs = lib.mkOption {
          type = lib.types.submodule {
            options = {
              wallet = lib.mkOption {
                type = lib.types.nullOr programType;
                default = null;
                description = "Preferred wallet/keyring manager";
              };
              fileBrowser = lib.mkOption {
                type = lib.types.nullOr programType;
                default = null;
                description = "Preferred file browser";
              };
              archiver = lib.mkOption {
                type = lib.types.nullOr programType;
                default = null;
                description = "Preferred archive manager";
              };
              textEditor = lib.mkOption {
                type = lib.types.nullOr programType;
                default = null;
                description = "Preferred text editor";
              };
              advancedTextEditor = lib.mkOption {
                type = lib.types.nullOr programType;
                default = null;
                description = "Preferred advanced text editor";
              };
              terminal = lib.mkOption {
                type = lib.types.nullOr terminalType;
                default = null;
                description = "Preferred terminal emulator for the main terminal window";
              };
              additionalTerminal = lib.mkOption {
                type = lib.types.nullOr terminalType;
                default = null;
                description = "Preferred terminal emulator for additional terminal windows (scratchpad and pop-ups)";
              };
              systemSettings = lib.mkOption {
                type = lib.types.nullOr programType;
                default = null;
                description = "Preferred system settings application";
              };
              networkSettings = lib.mkOption {
                type = lib.types.nullOr programType;
                default = null;
                description = "Preferred network settings application";
              };
              imageViewer = lib.mkOption {
                type = lib.types.nullOr programType;
                default = null;
                description = "Preferred image viewer";
              };
              imageEditor = lib.mkOption {
                type = lib.types.nullOr programType;
                default = null;
                description = "Preferred image editor/screenshot tool";
              };
              paintImageEditor = lib.mkOption {
                type = lib.types.nullOr programType;
                default = null;
                description = "Preferred paint/drawing application";
              };
              pdfViewer = lib.mkOption {
                type = lib.types.nullOr programType;
                default = null;
                description = "Preferred PDF viewer";
              };
              videoPlayer = lib.mkOption {
                type = lib.types.nullOr programType;
                default = null;
                description = "Preferred video player";
              };
              musicPlayer = lib.mkOption {
                type = lib.types.nullOr programType;
                default = null;
                description = "Preferred music player";
              };
              emailClient = lib.mkOption {
                type = lib.types.nullOr programType;
                default = null;
                description = "Preferred email client";
              };
              calendar = lib.mkOption {
                type = lib.types.nullOr programType;
                default = null;
                description = "Preferred calendar application";
              };
              contacts = lib.mkOption {
                type = lib.types.nullOr programType;
                default = null;
                description = "Preferred contacts application";
              };
              taskManager = lib.mkOption {
                type = lib.types.nullOr programType;
                default = null;
                description = "Preferred task/process manager";
              };
              diskUsage = lib.mkOption {
                type = lib.types.nullOr programType;
                default = null;
                description = "Preferred disk usage analyzer";
              };
              calculator = lib.mkOption {
                type = lib.types.nullOr programType;
                default = null;
                description = "Preferred calculator";
              };
              clock = lib.mkOption {
                type = lib.types.nullOr programType;
                default = null;
                description = "Preferred clock/timer application";
              };
              webBrowser = lib.mkOption {
                type = lib.types.nullOr programType;
                default = null;
                description = "Preferred web browser";
              };
              dialog = lib.mkOption {
                type = lib.types.nullOr programType;
                default = null;
                description = "Preferred dialog/prompt utility";
              };
              gitGui = lib.mkOption {
                type = lib.types.nullOr programType;
                default = null;
                description = "Preferred Git GUI client";
              };
              drawingProgram = lib.mkOption {
                type = lib.types.nullOr programType;
                default = null;
                description = "Preferred advanced drawing/image editing program";
              };
              appLauncher = lib.mkOption {
                type = lib.types.nullOr appLauncherType;
                default = null;
                description = "Preferred application launcher";
              };
            };
          };
          default = { };
          description = "Desktop program preferences";
        };

        additionalPrograms = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [ ];
          description = "Additional desktop programs to install (merged from all modules)";
        };
      };
    };
  };

  on.linux =
    let
      buildThemeBasePath =
        themeString:
        let
          parts = lib.splitString "/" themeString;
        in
        "${pkgs.${lib.head parts}}/share/icons/${lib.concatStringsSep "/" (lib.tail parts)}";

      mkIconValidation =
        config:
        { icons, primaryIcons }:
        let
          primary = buildThemeBasePath config.nx.preferences.theme.icons.primary;
          fallback = buildThemeBasePath config.nx.preferences.theme.icons.fallback;
          entryNames = entry: if builtins.isString entry then [ entry ] else entry;
          entryLabel = entry: lib.concatStringsSep "|" (entryNames entry);
          checkEntry =
            searchPaths: entry:
            let
              names = entryNames entry;
              label = entryLabel entry;
            in
            ''
              _found=false
              ${lib.concatMapStrings (name: ''
                if ! $_found; then
                  for _size in scalable 64x64 48x48 32x32 24x24 22x22 16x16; do
                    for _f in ${lib.concatMapStrings (p: "${p}/$_size/*/${name}.svg ") searchPaths}; do
                      [[ -f "$_f" ]] && _found=true && break 2
                    done
                  done
                fi
              '') names}
              if ! $_found; then
                echo "nx-icon-validation: icon '${label}' not found in icon themes" >&2
                exit 1
              fi
            '';
        in
        pkgs.runCommand "nx-icon-validation" { } ''
          ${lib.concatMapStrings (checkEntry [
            primary
            fallback
          ]) icons}
          ${lib.concatMapStrings (checkEntry [ primary ]) primaryIcons}
          mkdir $out
        '';

      mkScript =
        config:
        let
          primary = buildThemeBasePath config.nx.preferences.theme.icons.primary;
          fallback = buildThemeBasePath config.nx.preferences.theme.icons.fallback;
        in
        pkgs.writeScriptBin "nx-resolve-icon" ''
          #!${pkgs.bash}/bin/bash
          all=false
          search=false
          app=false
          themes="both"
          while [[ "$1" == -* ]]; do
            case "$1" in
              --all) all=true ;;
              --search) search=true ;;
              --app) app=true ;;
              --primary)
                if [[ "$themes" == "secondary" ]]; then
                  echo "nx-resolve-icon: --primary and --secondary are mutually exclusive" >&2; exit 1
                fi
                themes="primary" ;;
              --secondary)
                if [[ "$themes" == "primary" ]]; then
                  echo "nx-resolve-icon: --primary and --secondary are mutually exclusive" >&2; exit 1
                fi
                themes="secondary" ;;
              *) echo "nx-resolve-icon: unknown option '$1'" >&2; exit 1 ;;
            esac
            shift
          done
          if [[ $# -eq 0 ]]; then
            echo "nx-resolve-icon: icon name required" >&2
            exit 1
          fi
          if [[ $# -gt 1 ]]; then
            echo "nx-resolve-icon: too many arguments" >&2
            exit 1
          fi
          icon_name="$1"
          if [[ "$icon_name" == /* ]]; then echo "$icon_name"; exit 0; fi
          found=false
          _check_theme() {
            local f="$1"
            [[ "$themes" == "both" ]] && return 0
            [[ "$themes" == "primary" && "$f" == ${primary}/* ]] && return 0
            [[ "$themes" == "secondary" && "$f" == ${fallback}/* ]] && return 0
            return 1
          }
          _check_app() {
            local f="$1"
            $app || return 0
            local dir="''${f%/*}"
            local cat="''${dir##*/}"
            [[ "$cat" == "apps" || "$cat" == "categories" ]] && return 0
            return 1
          }
          if $search; then
            _remaining="$icon_name"
            while [[ -n "$_remaining" ]]; do
              _pattern="''${_remaining%%|*}"
              if [[ "$_remaining" == *"|"* ]]; then _remaining="''${_remaining#*|}"; else _remaining=""; fi
              for size in scalable 64x64 48x48 32x32 24x24 22x22 16x16; do
                for iconfile in "${primary}/$size"/*/*.svg "${fallback}/$size"/*/*.svg; do
                  [[ -f "$iconfile" ]] || continue
                  _check_theme "$iconfile" || continue
                  _check_app "$iconfile" || continue
                  base="''${iconfile##*/}"
                  base="''${base%.svg}"
                  if [[ "$base" == *"$_pattern"* ]]; then
                    echo "$iconfile"
                    if $all; then found=true; else exit 0; fi
                  fi
                done
              done
            done
          else
            _remaining="$icon_name"
            while [[ -n "$_remaining" ]]; do
              _name="''${_remaining%%|*}"
              if [[ "$_remaining" == *"|"* ]]; then _remaining="''${_remaining#*|}"; else _remaining=""; fi
              for size in scalable 64x64 48x48 32x32 24x24 22x22 16x16; do
                for iconfile in "${primary}/$size"/*/"$_name.svg"; do
                  if [[ -f "$iconfile" ]] && _check_theme "$iconfile" && _check_app "$iconfile"; then
                    echo "$iconfile"
                    if $all; then found=true; else exit 0; fi
                  fi
                done
                for iconfile in "${fallback}/$size"/*/"$_name.svg"; do
                  if [[ -f "$iconfile" ]] && _check_theme "$iconfile" && _check_app "$iconfile"; then
                    echo "$iconfile"
                    if $all; then found=true; else exit 0; fi
                  fi
                done
              done
            done
          fi
          $found && exit 0 || exit 1
        '';
    in
    {
      enabled = config: {
        nx.lib.iconResolveScript = lib.mkDefault (mkScript config);
        nx.lib.icons = [
          "dialog-information"
          "dialog-warning"
          "dialog-error"
          "preferences-desktop-notification"
          "emblem-synchronizing"
          "emblem-ok-symbolic"
          "email"
          "chat-symbolic"
          "syncthing"
          "com.valvesoftware.Steam"
          "system-suspend"
          "system-lock-screen"
          "audio-volume-medium"
          "audio-volume-muted"
          "application-certificate"
          "list-add"
          "list-remove"
          "go-down"
          "checkmark"
          "folder-sync"
          "system-reboot"
          "archive"
          "applications-science"
          "drive-harddisk"
          "computer-fail"
        ];
      };
      standalone = config: {
        home.packages = [
          config.nx.lib.iconResolveScript
        ]
        ++ lib.optionals helpers.isHostArchitecture [
          (mkIconValidation config {
            icons = config.nx.lib.icons;
            primaryIcons = config.nx.lib.primaryIcons;
          })
        ];
      };
      system = config: {
        environment.systemPackages = [ config.nx.lib.iconResolveScript ];
        system.extraDependencies = lib.optionals helpers.isHostArchitecture [
          (mkIconValidation config {
            icons = config.nx.lib.icons;
            primaryIcons = config.nx.lib.primaryIcons;
          })
        ];
      };
    };

  on.darwin.enabled = config: {
    nx.lib.iconResolveScript = self.dummyPackage pkgs "iconResolveScript";
  };
}
