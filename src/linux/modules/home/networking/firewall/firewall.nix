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
    };
}
