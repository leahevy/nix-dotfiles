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
    enabled = config: {
      nx.linux.monitoring.journal-watcher.ignorePatterns = [
        {
          tag = "pam_rssh";
          string = "None of these keys passed authentication";
        }
      ];
    };

    linux.system = config: {
      security.pam.rssh.enable = true;
      security.pam.services.sudo.rssh = true;
    };
  };
}
