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
  name = "firewall";

  group = "networking";
  input = "linux";
  namespace = "home";

  assertions = [
    {
      assertion = self.host.isModuleEnabled "networking.firewall";
      message = "The firewall home module requires the firewall system module to be enabled";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    {
      home.shellAliases = {
        firewall = "sudo nixos-firewall-tool";
        firewall-open-tcp = "sudo nixos-firewall-tool open tcp";
        firewall-open-udp = "sudo nixos-firewall-tool open udp";
        firewall-show = "sudo nixos-firewall-tool show";
        firewall-reset = "sudo nixos-firewall-tool reset";
      };

      home.packages = [
        (pkgs.writeShellScriptBin "firewall-open-script" ''
          #!/usr/bin/env bash
          set -euo pipefail

          if [ $# -eq 0 ]; then
            echo "Usage: firewall-open-script PORT1/PROTOCOL PORT2/PROTOCOL ..."
            echo "Example: firewall-open-script 4549/tcp 4171/udp 4175/udp"
            exit 1
          fi

          OPENED_PORTS=()
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

          echo "Opening firewall ports..."

          for port_spec in "$@"; do
            if [[ "$port_spec" =~ ^([0-9]+)/(tcp|udp)$ ]]; then
              port="''${BASH_REMATCH[1]}"
              protocol="''${BASH_REMATCH[2]}"

              if sudo nixos-firewall-tool open "$protocol" "$port"; then
                OPENED_PORTS+=("$port_spec")
                echo "Opened $protocol port $port"
              else
                echo "Failed to open $protocol port $port"
                exit 1
              fi
            else
              echo "Invalid port specification: $port_spec"
              echo "Format should be: PORT/PROTOCOL (e.g., 4549/tcp, 4171/udp)"
              exit 1
            fi
          done

          echo "All ports opened: ''${OPENED_PORTS[*]}"
          echo "Press any key to close ports and exit..."
          if read -n 1 -s 2>/dev/null; then
            echo ""
            echo "Key pressed. Closing ports..."
          fi
        '')
      ];
    };
}
