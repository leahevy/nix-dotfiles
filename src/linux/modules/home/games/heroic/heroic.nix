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
  name = "heroic";

  group = "games";
  input = "linux";
  namespace = "home";

  submodules = {
    linux = {
      games = {
        utils = true;
      };
      graphics = {
        opengl = true;
      };
    };
  };

  defaults = {
    withWayland = false;
    games = {
      stardewValley = false;
      torchlightII = false;
    };
    additionalGameStateDirs = [ ];
    withUmu = true;
    portsPerGame = {
      torchlightII = {
        tcp = [
          4549
          27036
          27037
        ]
        ++ lib.map (n: 27015 + n) (lib.range 0 15);
        udp = [
          4171
          4175
          4179
          4549
          4380
        ]
        ++ lib.map (n: 27000 + n) (lib.range 0 31);
      };
    };
    persistentOpenPortsForGames = {
      torchlightII = false;
    };
    additionalTCPPortsToOpen = [ ];
    additionalUDPPortsToOpen = [ ];
  };

  configuration =
    context@{ config, options, ... }:
    let
      withWayland = self.settings.withWayland;

      generateGameFirewallScript =
        gameName: gameConfig:
        let
          tcpPorts = gameConfig.tcp or [ ];
          udpPorts = gameConfig.udp or [ ];
          hasAnyPorts = (tcpPorts != [ ]) || (udpPorts != [ ]);
          isGameEnabled = self.settings.games.${gameName} or false;
          isPersistent = self.settings.persistentOpenPortsForGames.${gameName} or false;
          shouldCreateScript = isGameEnabled && hasAnyPorts && !isPersistent;
        in
        lib.optionalAttrs shouldCreateScript {
          "${gameName}-open-firewall" = pkgs.writeShellScriptBin "${gameName}-open-firewall" ''
            #!/usr/bin/env bash
            set -euo pipefail

            OPENED_TCP_PORTS=()
            OPENED_UDP_PORTS=()
            CLEANUP_DONE=false

            sudo -v
            (while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null) &
            SUDO_PID=$!

            cleanup() {
              if [ "$CLEANUP_DONE" = "true" ]; then
                return
              fi
              CLEANUP_DONE=true

              if [[ -n "''${SUDO_PID:-}" ]]; then
                kill "$SUDO_PID" 2>/dev/null || true
              fi

              echo ""
              echo "Resetting firewall to system configuration..."
              sudo nixos-firewall-tool reset
              echo "Firewall reset complete."
            }

            interrupt_handler() {
              echo ""
              echo "Interrupted. Cleaning up..."
              cleanup
              exit 0
            }

            trap cleanup EXIT
            trap interrupt_handler INT TERM

            echo "Opening firewall ports for ${gameName}..."

            ${lib.concatMapStringsSep "\n" (port: ''
              if sudo nixos-firewall-tool open tcp ${toString port}; then
                OPENED_TCP_PORTS+=(${toString port})
                echo "Opened TCP port ${toString port}"
              else
                echo "Failed to open TCP port ${toString port}"
                exit 1
              fi
            '') tcpPorts}

            ${lib.concatMapStringsSep "\n" (port: ''
              if sudo nixos-firewall-tool open udp ${toString port}; then
                OPENED_UDP_PORTS+=(${toString port})
                echo "Opened UDP port ${toString port}"
              else
                echo "Failed to open UDP port ${toString port}"
                exit 1
              fi
            '') udpPorts}

            echo "All ports opened for ${gameName}. Press any key to close ports and exit..."
            if read -n 1 -s 2>/dev/null; then
              echo ""
              echo "Key pressed. Closing ports..."
            fi
          '';
        };

      gameFirewallScripts = lib.mapAttrs generateGameFirewallScript self.settings.portsPerGame;
      allGameScripts = lib.flatten (
        lib.attrValues (
          lib.mapAttrs (name: scriptSet: lib.attrValues scriptSet) (
            lib.filterAttrs (name: value: value != { }) gameFirewallScripts
          )
        )
      );
    in
    {
      home.packages =
        with pkgs-unstable;
        [
          heroic
          steam-run
          mangohud
          protonup
          protontricks
          lutris
          bottles
          winetricks
          (if withWayland then wineWowPackages.waylandFull else wineWowPackages.stable)
        ]
        ++ allGameScripts;

      home.persistence."${self.persist}" = {
        directories = [
          ".config/heroic"
          ".local/share/comet"
          ".local/state/Heroic/logs"
          ".config/unity3d"
          ".local/share/GOG.com"
        ]
        ++ lib.optionals self.settings.games.stardewValley [
          ".config/StardewValley"
        ]
        ++ lib.optionals self.settings.games.torchlightII [
          ".local/share/Runic Games/Torchlight 2"
        ]
        ++ lib.optionals self.settings.withUmu [
          ".local/share/umu"
          ".cache/umu"
          ".cache/umu-protonfixes"
        ]
        ++ self.settings.additionalGameStateDirs;
      };
    };
}
