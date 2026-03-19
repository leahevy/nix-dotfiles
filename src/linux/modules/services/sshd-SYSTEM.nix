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
  name = "sshd";

  group = "services";
  input = "linux";
  namespace = "system";

  submodules = {
    linux = {
      services = {
        fail2ban = true;
      };
    };
  };

  settings = {
    port = 22;
  };

  configuration =
    context@{ config, options, ... }:
    {
      services = {
        openssh = {
          enable = true;
          ports = [ self.settings.port ];
          settings = {
            PasswordAuthentication = false;
            AllowUsers = [ self.host.mainUser.username ];
            X11Forwarding = false;
            PermitRootLogin = "no";
          };
        };
      };

      # Already configured in system module as ssh keys should always be persisted!
      environment.persistence.${self.persist} = { };
    };
}
