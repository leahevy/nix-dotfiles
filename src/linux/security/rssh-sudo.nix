args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
{
  name = "rssh-sudo";

  group = "security";
  input = "linux";

  enableOnDeploymentModes = [
    "managed"
    "server"
  ];

  module = {
    linux.system = config: {
      security.pam.rssh.enable = true;
      security.pam.services.sudo.rssh = true;
    };
  };
}
