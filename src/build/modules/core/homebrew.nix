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
  brewEntryType = lib.types.either lib.types.str (
    lib.types.submodule {
      options = {
        name = lib.mkOption {
          type = lib.types.str;
          description = "Package name";
        };
        args = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Additional arguments (e.g. [\"HEAD\"])";
        };
        restartOnChanged = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Whether to restart the service when the formula changes";
        };
      };
    }
  );

  renderBrew =
    entry:
    if builtins.isString entry then
      "brew '${entry}'"
    else
      let
        parts = [
          "brew '${entry.name}'"
        ]
        ++
          lib.optional (entry.args != [ ])
            "args: [${lib.concatMapStringsSep ", " (a: "\"${a}\"") entry.args}]"
        ++ lib.optional entry.restartOnChanged "restart_service: :changed";
      in
      lib.concatStringsSep ", " parts;

  renderTap = tap: "tap '${tap}'";
  renderCask = cask: "cask '${cask}'";
in
{
  name = "homebrew";
  group = "core";
  input = "build";

  rawOptions = {
    nx.homebrew = {
      taps = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Homebrew taps to add";
      };
      brews = lib.mkOption {
        type = lib.types.listOf brewEntryType;
        default = [ ];
        description = "Homebrew formulae to install (string or attrset with name, args, restartOnChanged)";
      };
      casks = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Homebrew casks to install";
      };
      notes = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Named notes to display after brew sync (name = multi-line text)";
      };
      appdir = lib.mkOption {
        type = lib.types.str;
        default = "~/Applications";
        description = "Directory for cask application symlinks";
      };
      requireSha = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to require SHA verification for casks";
      };
    };
  };

  module = {
    linux.home =
      config:
      let
        cfg = config.nx.homebrew;
        hasTaps = cfg.taps != [ ];
        hasBrews = cfg.brews != [ ];
        hasCasks = cfg.casks != [ ];
        hasNotes = cfg.notes != { };
      in
      lib.mkIf (hasTaps || hasBrews || hasCasks || hasNotes) {
        assertions = [
          {
            assertion = !hasTaps;
            message = "nx.homebrew.taps is set but Homebrew is only supported on Darwin. Taps: ${builtins.toJSON cfg.taps}";
          }
          {
            assertion = !hasBrews;
            message = "nx.homebrew.brews is set but Homebrew is only supported on Darwin. Brews: ${
              builtins.toJSON (map (b: if builtins.isString b then b else b.name) cfg.brews)
            }";
          }
          {
            assertion = !hasCasks;
            message = "nx.homebrew.casks is set but Homebrew is only supported on Darwin. Casks: ${builtins.toJSON cfg.casks}";
          }
          {
            assertion = !hasNotes;
            message = "nx.homebrew.notes is set but Homebrew is only supported on Darwin. Notes: ${builtins.toJSON (builtins.attrNames cfg.notes)}";
          }
        ];
      };

    darwin.home =
      config:
      let
        cfg = config.nx.homebrew;
        hasContent = cfg.taps != [ ] || cfg.brews != [ ] || cfg.casks != [ ] || cfg.notes != { };

        invalidBrews = builtins.filter (
          entry: !(builtins.isString entry) && (entry.name or "" == "")
        ) cfg.brews;

        headerLine = "cask_args appdir: '${cfg.appdir}', require_sha: ${
          if cfg.requireSha then "true" else "false"
        }";

        brewfileContent = lib.concatStringsSep "\n" (
          [ headerLine ] ++ map renderTap cfg.taps ++ map renderBrew cfg.brews ++ map renderCask cfg.casks
        );
        brewfile = pkgs.writeText "Brewfile" brewfileContent;
      in
      lib.mkIf hasContent {
        assertions = [
          {
            assertion = invalidBrews == [ ];
            message = "nx.homebrew.brews contains entries with empty or missing 'name' field";
          }
        ];

        home.file = {
          ".local/bin/brew-install" = {
            text = ''
              #!/usr/bin/env bash
              set -euo pipefail

              if ! command -v brew &> /dev/null; then
                echo "Homebrew not found. Installing..."
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
              else
                echo "Homebrew is already installed."
              fi
            '';
            executable = true;
          };

          ".local/bin/brew-sync" = {
            text = ''
              #!/usr/bin/env bash
              set -euo pipefail

              RED='\033[1;31m'
              GREEN='\033[1;32m'
              WHITE='\033[1;37m'
              BLUE='\033[1;34m'
              MAGENTA='\033[1;35m'
              RESET='\033[0m'

              BREWFILE="${brewfile}"
              NEW_BREWFILE="$HOME/.local/state/homebrew/Brewfile.active"

              if [[ $EUID -eq 0 ]]; then
                echo -e "''${WHITE}Do not run this script as root!''${RESET}" >&2
                exit 1
              fi

              if ! command -v brew &> /dev/null; then
                echo -e "''${RED}Homebrew not found!''${RESET}" >&2
                echo -e "''${WHITE}Run ''${GREEN}brew-install''${WHITE} first to set up Homebrew.''${RESET}" >&2
                exit 1
              fi

              echo -e "''${WHITE}Configured packages:''${RESET}"
              ${lib.optionalString (cfg.taps != [ ]) ''
                echo
                echo -e "  ''${MAGENTA}Taps:''${RESET}"
                ${lib.concatMapStrings (tap: ''
                  echo -e "    ''${WHITE}${tap}''${RESET}"
                '') cfg.taps}
              ''}
              ${lib.optionalString (cfg.brews != [ ]) ''
                echo
                echo -e "  ''${MAGENTA}Brews:''${RESET}"
                ${lib.concatMapStrings (
                  entry:
                  let
                    name = if builtins.isString entry then entry else entry.name;
                  in
                  ''
                    echo -e "    ''${WHITE}${name}''${RESET}"
                  ''
                ) cfg.brews}
              ''}
              ${lib.optionalString (cfg.casks != [ ]) ''
                echo
                echo -e "  ''${MAGENTA}Casks:''${RESET}"
                ${lib.concatMapStrings (cask: ''
                  echo -e "    ''${WHITE}${cask}''${RESET}"
                '') cfg.casks}
              ''}
              echo

              if [[ "''${1:-}" != "-y" ]]; then
                read -rp "$(echo -e "''${WHITE}Proceed? [Y/n] ''${RESET}")" confirm
                if [[ ! "''${confirm:-yes}" =~ ^[Yy](es)?$ ]]; then
                  echo -e "''${RED}Aborted.''${RESET}"
                  exit 0
                fi
              fi

              sudo -v

              (while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null) &
              SUDO_PID=$!

              cleanup() {
                if [[ -n "''${SUDO_PID:-}" ]]; then
                  kill "$SUDO_PID" 2>/dev/null || true
                fi
              }
              trap cleanup EXIT INT TERM

              echo
              echo -e "''${WHITE}Updating Homebrew...''${RESET}"
              GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null HOME=/tmp brew update --quiet
              echo

              echo -e "''${WHITE}Installing packages from Brewfile...''${RESET}"
              GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null HOME=/tmp brew bundle --file="$BREWFILE" --quiet
              echo

              echo -e "''${WHITE}Removing packages not in Brewfile...''${RESET}"
              GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null HOME=/tmp brew bundle cleanup --file="$BREWFILE" --force --quiet
              echo

              echo -e "''${WHITE}Cleaning up old versions...''${RESET}"
              GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null HOME=/tmp brew cleanup --prune=all --quiet
              echo

              echo -e "''${WHITE}Upgrading packages...''${RESET}"
              GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null HOME=/tmp brew upgrade -g
              echo

              cp "$BREWFILE" "$NEW_BREWFILE"

              echo -e "''${GREEN}Brew environment synced.''${RESET}"
              ${lib.concatStringsSep "\n" (
                lib.mapAttrsToList (
                  name: content:
                  let
                    lines = lib.splitString "\n" content;
                    lineCount = builtins.length (builtins.filter (l: l != "") lines);
                  in
                  if lineCount <= 1 then
                    ''
                      echo
                      echo -e "  ''${MAGENTA}${name}: ''${WHITE}${lib.concatStringsSep "" lines}''${RESET}"
                    ''
                  else
                    ''
                      echo
                      echo -e "  ''${MAGENTA}${name}:''${RESET}"
                      echo
                      ${lib.concatMapStrings (line: ''
                        ${
                          if lib.hasPrefix "# " line then
                            ''echo -e "    ''${RED}${line}''${RESET}"''
                          else if lib.hasPrefix "##" line then
                            ''echo -e "    ''${BLUE}${line}''${RESET}"''
                          else
                            ''echo -e "    ''${WHITE}${line}''${RESET}"''
                        }
                      '') lines}
                    ''
                ) cfg.notes
              )}
            '';
            executable = true;
          };

          ".local/state/homebrew/Brewfile".source = brewfile;
        };

        home.persistence."${self.persist}" = {
          directories = [
            ".local/state/homebrew"
          ];
        };
      };
  };
}
