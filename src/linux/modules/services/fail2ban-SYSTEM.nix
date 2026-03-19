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
  name = "fail2ban";

  group = "services";
  input = "linux";
  namespace = "system";

  configuration =
    context@{ config, options, ... }:
    {
      services.fail2ban = {
        enable = true;
      };

      environment.persistence."${self.persist}" = {
        directories = [
          "/var/lib/fail2ban"
        ];
      };
    };
}
