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
  configuration =
    context@{ config, options, ... }:
    {
      services.printing.enable = helpers.ifSet self.host.settings.system.printing.enabled false;

      environment.persistence.${self.persist} = {
        directories = [
          "/var/lib/cups"
          "/var/cache/cups"
          "/etc/cups"
        ];
      };
    };
}
