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

  defaults = {
    openWebServer = true;
    additionalTCPPorts = [ ];
    additionalUDPPortRanges = [ ]; # List of { from = INT; to = INT; }
  };

  configuration =
    context@{ config, options, ... }:
    {
      networking.firewall = {
        enable = true;
        allowedTCPPorts =
          (
            if self.settings.openWebServer then
              [
                80
                443
              ]
            else
              [ ]
          )
          ++ self.settings.additionalTCPPorts;
        allowedUDPPortRanges = self.settings.additionalUDPPortRanges;
      };
    };
}
