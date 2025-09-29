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

  assertions = [
    {
      assertion = self.user.isModuleEnabled "software.flatpack";
      message = "Requires linux.software.flatpack home-manager module to be enabled!";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    let
      dataDir = "${self.user.home}/.local/share/nx-flatpack";
      stateFile = "${dataDir}/state.json";

      manageFlatpaksScript = pkgs.writeShellScript "manage-flatpaks" ''
        set -euo pipefail

        mkdir -p "${dataDir}"

        for i in {1..5}; do
          if ${pkgs.flatpak}/bin/flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo; then
            break
          else
            echo "Failed to add Flathub repository (attempt $i/5), retrying in 5 seconds..."
            sleep 5
          fi
        done

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
              echo "Installing $package_id"
              for j in {1..5}; do
                if ${pkgs.flatpak}/bin/flatpak install --user --noninteractive flathub "$package_id"; then
                  echo "Successfully installed $package_id"
                  break
                else
                  echo "Failed to install $package_id (attempt $j/3)"
                  if [[ $j -lt 3 ]]; then
                    echo "Retrying in 10 seconds..."
                    sleep 10
                  else
                    echo "Giving up on $package_id after 3 attempts"
                  fi
                fi
              done
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
            echo "Removing orphaned package $installed_package"
            ${pkgs.flatpak}/bin/flatpak uninstall --user --noninteractive "$installed_package" || {
              echo "Failed to remove $installed_package, continuing..."
            }
          fi
        done <<< "$INSTALLED"

        printf '%s\n' "''${DESIRED_PACKAGES[@]}" | ${pkgs.jq}/bin/jq -R -s -c 'split("\n") | map(select(. != ""))' > "${stateFile}"

        echo "Flatpack management completed"
      '';
    in
    {
      home.persistence."${self.persist}" = {
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
        Install = {
          WantedBy = [ "default.target" ];
        };
        Service = {
          Type = "simple";
          ExecStart = manageFlatpaksScript;
          Environment = [
            "PATH=${
              lib.makeBinPath [
                pkgs.bash
                pkgs.coreutils
                pkgs.gnugrep
                pkgs.flatpak
                pkgs.jq
              ]
            }"
          ];
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
}
