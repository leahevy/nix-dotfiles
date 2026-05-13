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

  submodules = {
    linux = {
      services = {
        fail2ban = true;
      };
    };
  };

  settings = {
    port = 22;
    vmPort = 2323;
  };

  module = {
    linux.system = config: {
      assertions = [
        {
          assertion =
            config.nx.profile.host.remote.initrdSSHHostPrivateKey == null
            || config.nx.profile.host.remote.initrdSSHServicePort != self.settings.port;
          message = "host.remote.initrdSSHServicePort must not equal the main sshd port (${toString self.settings.port})!";
        }
      ];

      services = {
        openssh = {
          enable = true;
          ports = [ self.settings.port ];
          settings = {
            PasswordAuthentication = false;
            KbdInteractiveAuthentication = false;
            PermitEmptyPasswords = false;
            AllowUsers = [ self.host.mainUser.username ];
            X11Forwarding = false;
            PermitRootLogin = "no";
          };
        };
      };

      # Already configured in system module as ssh keys should always be persisted!
      environment.persistence.${self.persist} = { };
    };

    virtual.linux.system = config: {
      virtualisation.vmVariant = {
        virtualisation.forwardPorts = [
          {
            from = "host";
            host.port = self.settings.vmPort;
            guest.port = self.settings.port;
          }
        ];
      };
    };
  };
}
