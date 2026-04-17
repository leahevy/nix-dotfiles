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

  group = "services";
  input = "common";

  module = {
    home = config: {
      services = {
        ssh-agent.enable = true;
      };

      home.sessionVariables = lib.mkIf self.isLinux {
        SSH_AUTH_SOCK = "$XDG_RUNTIME_DIR/ssh-agent";
      };

      home.persistence."${self.persist}" = {
        directories = [
          ".ssh"
        ];
      };
    };
  };
}
