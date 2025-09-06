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
      services = {
        openssh = {
          enable = true;
        };
      };

      # Already configured in system module as ssh keys should always be persisted!
      environment.persistence.${self.persist} = { };
    };
}
