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
  namespace = "home";

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
          ${pkgs.libnotify}/bin/notify-send "Flatpack" "Failed to add FlatHub repository" || true
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
              ${pkgs.libnotify}/bin/notify-send "Flatpack" "Installing $package_id" || true
              for j in {1..5}; do
                if ${pkgs.flatpak}/bin/flatpak install --user --noninteractive flathub "$package_id"; then
                  ${pkgs.libnotify}/bin/notify-send "Flatpack" "Successfully installed $package_id" || true
                  break
                else
                  echo "Failed to install $package_id (attempt $j/5)"
                  if [[ $j -lt 5 ]]; then
                    echo "Retrying in 10 seconds..."
                    sleep 10
                  else
                    ${pkgs.libnotify}/bin/notify-send "Flatpack" "Failed to install $package_id after 5 attempts" || true
                  fi
                fi
              done
            else
              ${pkgs.libnotify}/bin/notify-send "Flatpack" "Updating $package_id" || true
              if ${pkgs.flatpak}/bin/flatpak update --user --noninteractive "$package_id"; then
                ${pkgs.libnotify}/bin/notify-send "Flatpack" "Successfully updated $package_id" || true
              else
                ${pkgs.libnotify}/bin/notify-send "Flatpack" "Failed to update $package_id" || true
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
            ${pkgs.libnotify}/bin/notify-send "Flatpack" "Removing orphaned package $installed_package" || true
            if ${pkgs.flatpak}/bin/flatpak uninstall --user --noninteractive "$installed_package"; then
              ${pkgs.libnotify}/bin/notify-send "Flatpack" "Successfully removed $installed_package" || true
            else
              ${pkgs.libnotify}/bin/notify-send "Flatpack" "Failed to remove $installed_package" || true
            fi
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
}
