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
  name = "ssh-agent";

  configuration =
    context@{ config, options, ... }:
    {
      services = {
        ssh-agent.enable = true;
      };

      home.persistence."${self.persist}" = {
        directories = [
          ".ssh"
        ];
      };
    };
}
