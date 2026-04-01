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

  dmenuOptsType = lib.types.submodule {
    options = {
      prompt = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Prompt text";
      };
      width = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Menu width";
      };
      lines = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Number of lines to show";
      };
      placeholder = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Placeholder text";
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

    nx.cache.icons = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Cache mapping icon names to nix store paths, built from the active icon themes";
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

      buildIconCache =
        config:
        let
          primaryBase = buildThemeBasePath config.nx.preferences.theme.icons.primary;
          fallbackBase = buildThemeBasePath config.nx.preferences.theme.icons.fallback;
          cacheScript = pkgs.writeText "nx-build-icon-cache.py" ''
            import json, os, sys

            def scan_size(base, key, size, cache):
                size_dir = os.path.join(base, size)
                if not os.path.isdir(size_dir):
                    return
                try:
                    categories = sorted(os.scandir(size_dir), key=lambda e: e.name)
                except OSError:
                    return
                for cat in categories:
                    if not cat.is_dir(follow_symlinks=True):
                        continue
                    try:
                        files = sorted(os.scandir(cat.path), key=lambda e: e.name)
                    except OSError:
                        continue
                    for f in files:
                        if f.name.endswith('.svg') or f.name.endswith('.png'):
                            cache[f.name[:-4]] = [key, os.path.relpath(f.path, base)]

            primary_base, fallback_base = sys.argv[1], sys.argv[2]
            sizes = ["scalable", "64x64", "48x48", "32x32", "24x24", "22x22", "16x16"]
            cache = {}
            for size in reversed(sizes):
                scan_size(fallback_base, "f", size, cache)
                scan_size(primary_base, "p", size, cache)
            sys.stdout.write(json.dumps(cache))
          '';
          cacheDrv = pkgs.runCommand "nx-icon-cache" { } ''
            ${pkgs.python3}/bin/python3 ${cacheScript} ${primaryBase} ${fallbackBase} > $out
          '';
          rawCache = builtins.fromJSON (builtins.readFile cacheDrv);
        in
        lib.mapAttrs (
          _: v:
          if builtins.elemAt v 0 == "p" then
            "${primaryBase}/${builtins.elemAt v 1}"
          else
            "${fallbackBase}/${builtins.elemAt v 1}"
        ) rawCache;

      mkScript =
        config:
        let
          primary = buildThemeBasePath config.nx.preferences.theme.icons.primary;
          fallback = buildThemeBasePath config.nx.preferences.theme.icons.fallback;
        in
        pkgs.writeScriptBin "nx-resolve-icon" ''
          #!${pkgs.bash}/bin/bash
          all=false
          if [[ "$1" == "--all" ]]; then
            all=true
            shift
          elif [[ "$1" == -* ]]; then
            echo "nx-resolve-icon: unknown option '$1'" >&2
            exit 1
          fi
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
          for size in scalable 64x64 48x48 32x32 24x24 22x22 16x16; do
            for iconfile in "${primary}/$size"/*/"$icon_name.svg"; do
              if [[ -f "$iconfile" ]]; then
                echo "$iconfile"
                if $all; then found=true; else exit 0; fi
              fi
            done
            for iconfile in "${fallback}/$size"/*/"$icon_name.svg"; do
              if [[ -f "$iconfile" ]]; then
                echo "$iconfile"
                if $all; then found=true; else exit 0; fi
              fi
            done
          done
          $found && exit 0 || exit 1
        '';
    in
    {
      enabled = config: {
        nx.lib.iconResolveScript = lib.mkDefault (mkScript config);
        nx.cache.icons = lib.mkDefault (buildIconCache config);
      };
      standalone = config: {
        home.packages = [ config.nx.lib.iconResolveScript ];
      };
      system = config: {
        environment.systemPackages = [ config.nx.lib.iconResolveScript ];
      };
    };
}
