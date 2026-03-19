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
  namespace = "system";

  assertions = [
    {
      assertion = self.user.isModuleEnabled "games.heroic";
      message = "The heroic system module requires the heroic home module to be enabled";
    }
    {
      assertion = self.isModuleEnabled "networking.firewall";
      message = "The heroic system module requires the firewall system module to be enabled";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    let
      heroicHomeConfig = self.user.getModuleConfig "games.heroic";
      portsPerGame = heroicHomeConfig.portsPerGame or { };
      persistentOpenPortsForGames = heroicHomeConfig.persistentOpenPortsForGames or { };

      persistentTcpPorts = lib.flatten (
        lib.mapAttrsToList (
          gameName: isPersistent:
          let
            gameConfig = portsPerGame.${gameName} or { };
            tcpPorts = gameConfig.tcp or [ ];
            isGameEnabled = heroicHomeConfig.games.${gameName} or false;
          in
          lib.optionals (isPersistent && isGameEnabled) tcpPorts
        ) persistentOpenPortsForGames
      );

      persistentUdpPortRanges = lib.flatten (
        lib.mapAttrsToList (
          gameName: isPersistent:
          let
            gameConfig = portsPerGame.${gameName} or { };
            udpPorts = gameConfig.udp or [ ];
            isGameEnabled = heroicHomeConfig.games.${gameName} or false;
          in
          lib.optionals (isPersistent && isGameEnabled) (
            map (port: {
              from = port;
              to = port;
            }) udpPorts
          )
        ) persistentOpenPortsForGames
      );
    in
    {
      networking.firewall = {
        allowedTCPPorts = persistentTcpPorts ++ (heroicHomeConfig.additionalTCPPortsToOpen or [ ]);
        allowedUDPPortRanges =
          persistentUdpPortRanges
          ++ (map (port: {
            from = port;
            to = port;
          }) (heroicHomeConfig.additionalUDPPortsToOpen or [ ]));
      };
    };
}
