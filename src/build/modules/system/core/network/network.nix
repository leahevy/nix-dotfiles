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
  host = self.host;
  ifSet = helpers.ifSet;
in
{
  name = "network";

  configuration =
    context@{ config, options, ... }:
    {
      networking.hostName = host.hostname;
      networking.wireless.enable = ifSet host.settings.networking.wifi.enabled false;
      networking.useDHCP = !host.settings.networking.useNetworkManager;
      networking.nftables.enable = true;

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
                    };

                    ipv4 = {
                      method = "auto";
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
          { }
      );
    };
}
