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
  name = "homebrew";

  group = "software";
  input = "darwin";
  namespace = "home";

  settings = {
    headers = [ "cask_args appdir: '~/Applications', require_sha: true" ];
    taps = [ ];
    brews = [ ];
    casks = [ ];
    notes = [ ];
  };

  assertions = [
    {
      assertion = self.isDarwin;
      message = "Homebrew only works on Darwin systems.";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    {
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

            BREWFILE="$HOME/.config/homebrew/Brewfile"

            if [[ $EUID -eq 0 ]]; then
              echo -e "''${WHITE}Do not run this script as root!''${RESET}" >&2
              exit 1
            fi

            if [[ ! -f "$BREWFILE" ]]; then
              echo -e "''${RED}Brewfile not found at $BREWFILE!''${RESET}" >&2
              exit 1
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

            cp "$BREWFILE" "$BREWFILE.active"

            echo -e "''${GREEN}Brew environment synced.''${RESET}"
            ${if self.settings.notes != [ ] then "echo" else ""}
            ${lib.concatMapStrings (note: ''
              echo -e "  ''${MAGENTA}Note: ''${WHITE}${note}''${RESET}"
            '') self.settings.notes}
            if [[ -d "${self.user.home}/.config/homebrew" ]]; then
              for file in "${self.user.home}/.config/homebrew"/*.note; do
                if [[ -f "$file" ]]; then
                  echo
                  filename=$(basename "$file" .note)
                  content=$(cat "$file")
                  line_count=$(echo "$content" | wc -l)
                  if [[ $line_count -eq 1 ]]; then
                    echo -e "  ''${MAGENTA}$filename: ''${WHITE}$content''${RESET}"
                  else
                    echo -e "  ''${MAGENTA}$filename:''${RESET}"
                    echo
                    echo "$content" | while IFS= read -r line; do
                      if [[ "$line" =~ ^#[[:space:]] ]]; then
                        echo -e "    ''${RED}$line''${RESET}"
                      elif [[ "$line" =~ ^##+ ]]; then
                        echo -e "    ''${BLUE}$line''${RESET}"
                      else
                        echo -e "    ''${WHITE}$line''${RESET}"
                      fi
                    done
                  fi
                fi
              done
            fi
          '';
          executable = true;
        };
      };

      home.activation.brewfile = (self.hmLib config).dag.entryAfter [ "linkGeneration" ] ''
        run mkdir -p ${self.user.home}/.config/homebrew || true

        BREWFILE="${self.user.home}/.config/homebrew/Brewfile"
        BREWFILE_TMP="${self.user.home}/.config/homebrew/Brewfile.tmp"

        run echo -n "" > "$BREWFILE_TMP" || true

        ${lib.concatMapStrings (header: ''
          run echo "${lib.replaceStrings [ "~" ] [ self.user.home ] header}" >> "$BREWFILE_TMP" || true
        '') self.settings.headers}

        ${lib.concatMapStrings (tap: ''
          run echo "tap '${tap}'" >> "$BREWFILE_TMP" || true
        '') self.settings.taps}

        if [[ -d "${self.user.home}/.config/homebrew" ]]; then
          for file in "${self.user.home}/.config/homebrew"/*.tap; do
            if [[ -f "$file" ]]; then
              run cat "$file" >> "$BREWFILE_TMP" || true
            fi
          done
        fi

        ${lib.concatMapStrings (brew: ''
          run echo "brew '${brew}'" >> "$BREWFILE_TMP" || true
        '') self.settings.brews}

        ${lib.concatMapStrings (cask: ''
          run echo "cask '${cask}'" >> "$BREWFILE_TMP" || true
        '') self.settings.casks}

        if [[ -d "${self.user.home}/.config/homebrew" ]]; then
          for file in "${self.user.home}/.config/homebrew"/*.brew; do
            if [[ -f "$file" ]]; then
              run cat "$file" >> "$BREWFILE_TMP" || true
            fi
          done
        fi

        run cp "$BREWFILE_TMP" "$BREWFILE" || true
        run rm -f "$BREWFILE_TMP" || true
      '';

      home.persistence."${self.persist}" = {
        directories = [
          ".config/homebrew"
        ];
      };
    };
}
