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

      home.sessionVariables = {
        SSH_AUTH_SOCK = "$XDG_RUNTIME_DIR/ssh-agent";
      };

      home.persistence."${self.persist}" = {
        directories = [
          ".ssh"
        ];
      };
    };
}
