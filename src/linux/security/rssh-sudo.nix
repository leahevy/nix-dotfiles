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
        {
          tag = "pam_rssh";
          string = "No such file or directory \\(os error 2\\)";
          user = true;
          unitless = true;
        }
      ];
    };

    linux.system =
      config:
      let
        mainUser = config.users.users.${self.host.mainUser.username};
        agentSockPath = "/run/user/${toString mainUser.uid}/ssh-agent-forward";

        cutBin = helpers.packageFile args pkgs.coreutils "bin/cut";
        idBin = helpers.packageFile args pkgs.coreutils "bin/id";
        lnBin = helpers.packageFile args pkgs.coreutils "bin/ln";
        mvBin = helpers.packageFile args pkgs.coreutils "bin/mv";
        xauthBin = lib.getExe pkgs.xauth;

        xauthForwarding = ''
          if read proto cookie && [ -n "$DISPLAY" ]; then
            if [ "$(echo "$DISPLAY" | ${cutBin} -c1-10)" = "localhost:" ]; then
              echo add "unix:$(echo "$DISPLAY" | ${cutBin} -c11-)" "$proto" "$cookie"
            else
              echo add "$DISPLAY" "$proto" "$cookie"
            fi | ${xauthBin} -q -
          fi
        '';
      in
      {
        assertions = [
          {
            assertion = mainUser.uid != null;
            message = "rssh-sudo requires an explicit uid for the main user to pin the ssh agent socket path!";
          }
        ];

        security.pam.rssh.enable = true;
        security.pam.rssh.settings.ssh_agent_addr = agentSockPath;
        security.pam.services.sudo.rssh = true;

        environment.etc."ssh/sshrc".text = ''
          #!/bin/sh

          exec 1>&2

          ${lib.optionalString config.services.openssh.settings.X11Forwarding xauthForwarding}

          if [ -n "$SSH_AUTH_SOCK" ] && [ -S "$SSH_AUTH_SOCK" ]; then
            runtimeDir="/run/user/$(${idBin} -u)"

            if [ -d "$runtimeDir" ]; then
              ${lnBin} -sfn "$SSH_AUTH_SOCK" "$runtimeDir/ssh-agent-forward.new"
              ${mvBin} -Tf "$runtimeDir/ssh-agent-forward.new" "$runtimeDir/ssh-agent-forward"
            fi
          fi
        '';
      };
  };
}
