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
  namespace = "system";

  assertions = [
    {
      assertion = self.host.isModuleEnabled "software.flatpack";
      message = "Requires linux.software.flatpack nixos module to be enabled!";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    {
      services.flatpak.enable = true;

      environment.persistence."${self.persist}" = {
        directories = [
          "/var/lib/flatpak"
        ];
      };
    };
}
