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
  name = "apt";

  group = "core";
  input = "build";

  disableOnDarwin = true;

  rawOptions = {
    nx.apt = {
      packages = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "apt packages to install on Linux standalone systems";
      };
      hints = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Freeform hint strings shown after nx sync (e.g. PPAs to add manually)";
      };
      postInstallScripts = lib.mkOption {
        type = lib.types.listOf lib.types.package;
        default = [ ];
        description = "Executable store paths run after apt-sync on standalone Linux.";
      };
    };
  };

  module = {
    linux.standalone =
      config:
      let
        cfg = config.nx.apt;
        packagesFile = pkgs.writeText "apt-packages" (lib.concatStringsSep "\n" cfg.packages);
      in
      {
        home.file = {
          ".local/state/apt/packages.list".source = packagesFile;

          "${defs.binDir}/apt-hints" = {
            text = ''
              #!/usr/bin/env bash
              set -euo pipefail

              YELLOW='\033[1;33m'
              WHITE='\033[1;37m'
              RESET='\033[0m'

              ${
                if cfg.hints == [ ] then
                  "exit 0"
                else
                  lib.concatMapStringsSep "\n" (hint: ''
                    echo -e "''${YELLOW}Hint:''${RESET} ''${WHITE}${hint}''${RESET}"
                  '') cfg.hints
              }
            '';
            executable = true;
          };

          "${defs.binDir}/apt-sync" = {
            text = ''
              #!/usr/bin/env bash
              set -euo pipefail

              RED='\033[1;31m'
              GREEN='\033[1;32m'
              WHITE='\033[1;37m'
              MAGENTA='\033[1;35m'
              RESET='\033[0m'

              NEW_PKGFILE="${packagesFile}"
              ACTIVE_PKGFILE="''${HOME}/.local/state/apt/packages.active"

              if [[ $EUID -eq 0 ]]; then
                echo -e "''${WHITE}Do not run this script as root!''${RESET}" >&2
                exit 1
              fi

              new_pkgs=()
              while IFS= read -r line || [[ -n "''${line}" ]]; do
                [[ -z "''${line}" ]] && continue
                new_pkgs+=("''${line}")
              done < "''${NEW_PKGFILE}"

              old_pkgs=()
              if [[ -f "''${ACTIVE_PKGFILE}" ]]; then
                while IFS= read -r line || [[ -n "''${line}" ]]; do
                  [[ -z "''${line}" ]] && continue
                  old_pkgs+=("''${line}")
                done < "''${ACTIVE_PKGFILE}"
              fi

              to_remove=()
              for pkg in "''${old_pkgs[@]}"; do
                found=false
                for newpkg in "''${new_pkgs[@]}"; do
                  if [[ "''${pkg}" == "''${newpkg}" ]]; then
                    found=true
                    break
                  fi
                done
                if [[ "''${found}" == "false" ]]; then
                  to_remove+=("''${pkg}")
                fi
              done

              if [[ ''${#new_pkgs[@]} -eq 0 && ''${#to_remove[@]} -eq 0 ]]; then
                echo -e "''${WHITE}No packages configured.''${RESET}"
                exit 0
              fi

              echo -e "''${WHITE}Configured packages:''${RESET}"
              echo
              if [[ ''${#new_pkgs[@]} -gt 0 ]]; then
                echo -e "  ''${MAGENTA}Install:''${RESET}"
                for pkg in "''${new_pkgs[@]}"; do
                  echo -e "    ''${WHITE}''${pkg}''${RESET}"
                done
              fi
              if [[ ''${#to_remove[@]} -gt 0 ]]; then
                echo
                echo -e "  ''${MAGENTA}Remove:''${RESET}"
                for pkg in "''${to_remove[@]}"; do
                  echo -e "    ''${WHITE}''${pkg}''${RESET}"
                done
              fi
              echo

              if [[ "''${1:-}" != "-y" ]]; then
                read -rp "$(echo -e "''${WHITE}Proceed? [Y/n] ''${RESET}")" confirm
                if [[ ! "''${confirm:-yes}" =~ ^[Yy](es)?$ ]]; then
                  echo -e "''${RED}Aborted.''${RESET}"
                  exit 0
                fi
              fi

              ASKPASS_DIR="$(mktemp -d)"

              cleanup() {
                if [[ -n "''${FEEDER_PID:-}" ]]; then
                  kill "''${FEEDER_PID}" 2>/dev/null || true
                fi
                rm -rf "''${ASKPASS_DIR}"
              }
              trap cleanup EXIT INT TERM

              mkfifo -m 600 "''${ASKPASS_DIR}/fifo"
              printf '#!/bin/bash\nexec cat "$(dirname "$0")/fifo"\n' > "''${ASKPASS_DIR}/askpass"
              chmod 700 "''${ASKPASS_DIR}/askpass"
              export SUDO_ASKPASS="''${ASKPASS_DIR}/askpass"

              read -rsp "$(echo -e "''${WHITE}Password: ''${RESET}")" SUDO_PASSWORD
              echo

              if ! printf '%s\n' "''${SUDO_PASSWORD}" | sudo -S -k -v 2>/dev/null; then
                echo -e "''${RED}Invalid password!''${RESET}" >&2
                exit 1
              fi

              (while :; do printf '%s\n' "''${SUDO_PASSWORD}" > "''${ASKPASS_DIR}/fifo" || true; done) 2>/dev/null &
              FEEDER_PID=$!
              unset SUDO_PASSWORD

              export DEBIAN_FRONTEND=noninteractive

              echo
              echo -e "''${WHITE}Updating package lists...''${RESET}"
              sudo -A apt-get update -q
              echo

              if [[ ''${#new_pkgs[@]} -gt 0 ]]; then
                echo -e "''${WHITE}Installing packages...''${RESET}"
                sudo -A apt-get install -y "''${new_pkgs[@]}"
                echo
              fi

              if [[ ''${#to_remove[@]} -gt 0 ]]; then
                echo -e "''${WHITE}Removing packages...''${RESET}"
                sudo -A apt-get remove --purge -y "''${to_remove[@]}"
                echo
                echo -e "''${WHITE}Cleaning up...''${RESET}"
                sudo -A apt-get autoremove -y
                echo
              fi

              install -m 644 "''${NEW_PKGFILE}" "''${ACTIVE_PKGFILE}"
              echo -e "''${GREEN}Apt packages synced.''${RESET}"
            '';
            executable = true;
          };
        }
        // lib.optionalAttrs (cfg.postInstallScripts != [ ]) {
          "${defs.binDir}/install-hooks" = {
            text = ''
              #!/usr/bin/env bash
              set -euo pipefail

              WHITE='\033[1;37m'
              GREEN='\033[1;32m'
              RESET='\033[0m'

              ${lib.concatMapStringsSep "\n\n" (script: ''
                echo -e "''${WHITE}Running $(basename "${script}")...''${RESET}"
                "${script}"
              '') cfg.postInstallScripts}

              echo -e "''${GREEN}Post-install hooks complete.''${RESET}"
            '';
            executable = true;
          };
        };

        home.persistence."${self.persist}" = {
          directories = [ ".local/state/apt" ];
        };
      };
  };
}
