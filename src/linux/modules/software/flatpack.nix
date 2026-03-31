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
  name = "flatpack";

  group = "software";
  input = "linux";

  on = {
    home =
      config:
      let
        dataDir = "${self.user.home}/.local/share/nx-flatpack";
        stateFile = "${dataDir}/state.json";

        manageFlatpaksScript = pkgs.writeShellScript "manage-flatpaks" ''
          set -euo pipefail

          mkdir -p "${dataDir}"

          SUCCEEDED=0
          for i in {1..5}; do
            if ${pkgs.flatpak}/bin/flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo; then
              echo "Succeeded adding Flathub repository"
              SUCCEEDED=1
              break
            else
              echo "Failed to add Flathub repository (attempt $i/5), retrying in 5 seconds..."
              sleep 5
            fi
          done

          if [[ "$SUCCEEDED" != "1" ]]; then
            ${
              self.notifyUser {
                title = "Flatpack";
                body = "Failed to add FlatHub repository";
                icon = "dialog-error";
                urgency = "critical";
                validation = { inherit config; };
              }
            } || true
            exit 1
          fi

          DESIRED_PACKAGES=()
          if [[ -d "${dataDir}" ]]; then
            for file in "${dataDir}"/*.flatpack; do
              [[ -f "$file" ]] || continue
              package_id=$(basename "$file" .flatpack)
              DESIRED_PACKAGES+=("$package_id")
            done
          fi

          INSTALLED=$(${pkgs.flatpak}/bin/flatpak list --user --columns=application 2>/dev/null | tail -n +1 || echo "")

          for package_id in "''${DESIRED_PACKAGES[@]}"; do
            if [[ -n "$package_id" ]]; then
              if ! echo "$INSTALLED" | grep -q "^$package_id$"; then
                ${
                  self.notifyUser {
                    title = "Flatpack";
                    body = "Installing $package_id";
                    icon = "list-add";
                    urgency = "normal";
                    validation = { inherit config; };
                  }
                } || true
                for j in {1..5}; do
                  if ${pkgs.flatpak}/bin/flatpak install --user --noninteractive flathub "$package_id"; then
                    ${
                      self.notifyUser {
                        title = "Flatpack";
                        body = "Successfully installed $package_id";
                        icon = "list-add";
                        urgency = "normal";
                        validation = { inherit config; };
                      }
                    } || true
                    break
                  else
                    echo "Failed to install $package_id (attempt $j/5)"
                    if [[ $j -lt 5 ]]; then
                      echo "Retrying in 10 seconds..."
                      sleep 10
                    else
                      ${
                        self.notifyUser {
                          title = "Flatpack";
                          body = "Failed to install $package_id after 5 attempts";
                          icon = "dialog-error";
                          urgency = "critical";
                          validation = { inherit config; };
                        }
                      } || true
                    fi
                  fi
                done
              else
                ${
                  self.notifyUser {
                    title = "Flatpack";
                    body = "Updating $package_id";
                    icon = "go-down";
                    urgency = "normal";
                    validation = { inherit config; };
                  }
                } || true
                if ${pkgs.flatpak}/bin/flatpak update --user --noninteractive "$package_id"; then
                  ${
                    self.notifyUser {
                      title = "Flatpack";
                      body = "Successfully updated $package_id";
                      icon = "go-down";
                      urgency = "normal";
                      validation = { inherit config; };
                    }
                  } || true
                else
                  ${
                    self.notifyUser {
                      title = "Flatpack";
                      body = "Failed to update $package_id";
                      icon = "dialog-error";
                      urgency = "critical";
                      validation = { inherit config; };
                    }
                  } || true
                fi
              fi
            fi
          done

          while IFS= read -r installed_package; do
            [[ -n "$installed_package" ]] || continue
            found=false
            for desired_package in "''${DESIRED_PACKAGES[@]}"; do
              if [[ "$installed_package" == "$desired_package" ]]; then
                found=true
                break
              fi
            done
            if [[ "$found" == "false" ]] && [[ -f "${stateFile}" ]] && grep -q "\"$installed_package\"" "${stateFile}"; then
              ${
                self.notifyUser {
                  title = "Flatpack";
                  body = "Removing orphaned package $installed_package";
                  icon = "list-remove";
                  urgency = "normal";
                  validation = { inherit config; };
                }
              } || true
              if ${pkgs.flatpak}/bin/flatpak uninstall --user --noninteractive "$installed_package"; then
                ${
                  self.notifyUser {
                    title = "Flatpack";
                    body = "Successfully removed $installed_package";
                    icon = "list-remove";
                    urgency = "normal";
                    validation = { inherit config; };
                  }
                } || true
              else
                ${
                  self.notifyUser {
                    title = "Flatpack";
                    body = "Failed to remove $installed_package";
                    icon = "dialog-error";
                    urgency = "critical";
                    validation = { inherit config; };
                  }
                } || true
              fi
            fi
          done <<< "$INSTALLED"

          printf '%s\n' "''${DESIRED_PACKAGES[@]}" | ${pkgs.jq}/bin/jq -R -s -c 'split("\n") | map(select(. != ""))' > "${stateFile}"

          echo "Flatpack management completed"
        '';
      in
      {
        home.persistence."${self.persist.home}" = {
          directories = [
            ".local/share/nx-flatpack"
            ".local/share/flatpak"
          ];
        };

        xdg.systemDirs.data = [
          "/var/lib/flatpak/exports/share"
          "${self.user.home}/.local/share/flatpak/exports/share"
        ];

        systemd.user.services.flatpack-manager = {
          Unit = {
            Description = "Manage user Flatpak applications";
            After = [ "graphical-session.target" ];
          };
          Service = {
            Type = "oneshot";
            ExecStart = manageFlatpaksScript;
            Environment = [
              "PATH=${
                lib.makeBinPath [
                  pkgs.bash
                  pkgs.coreutils
                  pkgs.gnugrep
                  pkgs.flatpak
                  pkgs.jq
                  pkgs.libnotify
                ]
              }"
            ];
          };
        };

        systemd.user.timers.flatpack-manager = {
          Unit = {
            Description = "Regular Flatpak management timer";
            Requires = [ "flatpack-manager.service" ];
          };
          Install = {
            WantedBy = [ "timers.target" ];
          };
          Timer = {
            OnCalendar = [
              "*-*-* 18:00:00"
            ];
            Persistent = true;
            RandomizedDelaySec = "15m";
            OnBootSec = "30s";
          };
        };

        home.activation.flatpack-restart = (self.hmLib config).dag.entryAfter [ "reloadSystemd" ] ''
          if ${pkgs.systemd}/bin/systemctl --user is-system-running >/dev/null 2>&1; then
            run --quiet ${pkgs.systemd}/bin/systemctl --user restart flatpack-manager.service || true
          else
            echo "User systemd not available, flatpack-manager will start on login"
          fi
        '';
      };

    linux.system = config: {
      services.flatpak.enable = true;

      environment.persistence."${self.persist.system}" = {
        directories = [
          "/var/lib/flatpak"
        ];
      };
    };
  };
}
