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

    linux.system = config: {
      security.pam.rssh.enable = true;
      security.pam.services.sudo.rssh = true;
    };

    ifEnabled.common.shell.fish.home = config: {
      home.file."${config.xdg.configHome}/fish-init/10-ssh-auth-sock.fish".text = ''
        function __nx_refresh_ssh_auth_sock --on-event fish_prompt
          if test -z "$TMUX"; or test -z "$SSH_AUTH_SOCK"; or test -S "$SSH_AUTH_SOCK"
            return
          end

          set -l sock (command tmux show-environment SSH_AUTH_SOCK 2>/dev/null | string replace -r '^SSH_AUTH_SOCK=' "")

          if test -S "$sock"
            set -gx SSH_AUTH_SOCK $sock
          end
        end
      '';
    };
  };
}
