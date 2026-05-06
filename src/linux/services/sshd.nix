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
    linux.system =
      config:
      let
        buildUser = self.host.remote.buildUser;
        buildPublicSSHKey = self.host.remote.buildPublicSSHKey;
        hasBuildKey = buildPublicSSHKey != null;
      in
      {
        services = {
          openssh = {
            enable = true;
            ports = [ self.settings.port ];
            settings = {
              PasswordAuthentication = false;
              AllowUsers = lib.unique ([ self.host.mainUser.username ] ++ lib.optional hasBuildKey buildUser);
              X11Forwarding = false;
              PermitRootLogin = if hasBuildKey && buildUser == "root" then "prohibit-password" else "no";
            };
          };
        };

        users.users = lib.mkIf hasBuildKey {
          ${buildUser}.openssh.authorizedKeys.keys = [ buildPublicSSHKey ];
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
