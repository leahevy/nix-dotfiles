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
  name = "network";
  group = "core";
  input = "build";

  module = {
    system =
      config:
      let
        host = self.host;
        ifSet = helpers.ifSet;
      in
      {
        networking.hostName = host.hostname;
        networking.wireless.enable =
          if self.isVirtual then false else ifSet host.settings.networking.wifi.enabled false;
        networking.useDHCP = lib.mkForce (!host.settings.networking.useNetworkManager);
        networking.nftables.enable = true;
        networking.search = lib.mkIf (self.host.homeserverDomain != null) [
          self.host.homeserverDomain
        ];

        networking.networkmanager = (
          if host.settings.networking.useNetworkManager then
            {
              enable = true;
              settings = {
                main = {
                  no-auto-default = "*";
                };
              };
              ensureProfiles.profiles = (
                if host.ethernetDeviceName != null then
                  {
                    "Ethernet" = {
                      connection = {
                        id = "Ethernet";
                        type = "ethernet";
                        interface-name = ifSet host.ethernetDeviceName "";
                        uuid = helpers.generateUUID "ethernet-${host.ethernetDeviceName}";
                        autoconnect = true;
                        autoconnect-retries = 0;
                      };

                      ipv4 = {
                        method = "auto";
                        dhcp-timeout = 30;
                      };

                      ipv6 = {
                        method = "auto";
                        addr-gen-mode = "default";
                      };

                    };
                  }
                else
                  { }
              );
            }
          else
            {
              enable = false;
            }
        );

        services.resolved = {
          enable = true;
          extraConfig = lib.mkIf config.services.avahi.enable ''
            [Resolve]
            MulticastDNS=no
          '';
        };

        systemd.services.network-watchdog-ethernet =
          lib.mkIf (host.settings.networking.useNetworkManager && host.ethernetDeviceName != null)
            {
              description = "Recover Ethernet connection if NetworkManager loses its IP";
              serviceConfig = {
                Type = "oneshot";
                ExecStart = pkgs.writeShellScript "network-watchdog-ethernet" ''
                  _carrier=$(${pkgs.coreutils}/bin/cat /sys/class/net/${host.ethernetDeviceName}/carrier 2>/dev/null || echo 0)
                  if [[ "$_carrier" != "1" ]]; then
                    exit 0
                  fi
                  if ${pkgs.iproute2}/bin/ip -o addr show ${host.ethernetDeviceName} scope global | ${pkgs.gnugrep}/bin/grep -q 'inet '; then
                    exit 0
                  fi
                  ${pkgs.networkmanager}/bin/nmcli connection up Ethernet
                '';
              };
            };

        systemd.timers.network-watchdog-ethernet =
          lib.mkIf (host.settings.networking.useNetworkManager && host.ethernetDeviceName != null)
            {
              wantedBy = [ "timers.target" ];
              timerConfig = {
                OnBootSec = "3min";
                OnUnitInactiveSec = "2min";
                RandomizedDelaySec = 15;
              };
            };
      };
  };
}
