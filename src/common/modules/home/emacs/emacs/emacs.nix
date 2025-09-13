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
  configuration =
    context@{ config, options, ... }:
    let
      runtimeDir = if self.isDarwin then "$HOME/Library/Caches" else "$XDG_RUNTIME_DIR";
      emacsPackage = if self.isDarwin then pkgs.emacs-macport else pkgs.emacs-gtk;
      sshAgentEnabled = self.isLinux && (config.services.ssh-agent.enable or false);
    in
    {
      home.packages = [ emacsPackage ];

      home.sessionVariables = {
        VISUAL = lib.mkForce "emacs";
      };

      home.shellAliases = {
        emacs = if self.isDarwin
          then "TERM=xterm-256color emacsclient -t -a 'echo \"Emacs server is not ready yet... check with emacs-server-status\"'"
          else "emacsclient --server-file=\"${runtimeDir}/emacs-auth/emacs-server\" -c -a 'echo \"Emacs server is not ready yet... check with emacs-server-status\"' -t";
        emacs-server-restart =
          if self.isDarwin then
            "launchctl kickstart -k gui/$(id -u)/nx-emacs-daemon"
          else
            "systemctl --user restart nx-emacs-custom";
        emacs-server-status =
          if self.isDarwin then
            "launchctl print gui/$(id -u)/nx-emacs-daemon"
          else
            "systemctl --user status nx-emacs-custom";
      } // lib.optionalAttrs self.isLinux {
        emacs-gui = "emacsclient --server-file=\"${runtimeDir}/emacs-auth/emacs-server\" -c -a 'echo \"Emacs server is not ready yet... check with emacs-server-status\"'";
      };

      systemd.user.services.nx-emacs-custom = lib.mkIf self.isLinux {
        Unit = {
          Description = "Emacs text editor (custom)";
          After = [ "graphical-session.target" ] ++ lib.optional sshAgentEnabled "ssh-agent.service";
        }
        // lib.optionalAttrs sshAgentEnabled {
          Requires = [ "ssh-agent.service" ];
        };

        Service = {
          Type = "forking";

          ExecStart = ''
            ${emacsPackage}/bin/emacs --daemon \
              --eval "(setq server-name \"emacs-server\")" \
              --eval "(setq server-port 17777)" \
              --eval "(setq server-auth-dir \"%t/emacs-auth/\")" \
              --eval "(setq server-use-tcp t)"
          '';

          Restart = "always";
          RestartSec = "5s";

          RuntimeDirectory = "emacs-auth";
          RuntimeDirectoryMode = "0700";

          Environment = [
            "PATH=${emacsPackage}/bin:${config.home.homeDirectory}/.nix-profile/bin:/run/wrappers/bin:/etc/profiles/per-user/${config.home.username}/bin:/run/current-system/sw/bin"
          ]
          ++ lib.optional sshAgentEnabled "SSH_AUTH_SOCK=%t/ssh-agent";
        };

        Install = {
          WantedBy = [ "graphical-session.target" ];
        };
      };

      launchd.agents.nx-emacs-daemon = lib.mkIf self.isDarwin {
        enable = true;
        config = {
          Label = "nx-emacs-daemon";
          ProgramArguments = [
            "/bin/sh"
            "-c"
            "exec ${emacsPackage}/bin/emacs --fg-daemon"
          ];
          RunAtLoad = true;
          ProcessType = "Interactive";
          KeepAlive = {
            SuccessfulExit = true;
          };
          StandardOutPath = "${config.home.homeDirectory}/Library/Logs/nx-emacs-daemon.log";
          StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/nx-emacs-daemon.log";
          EnvironmentVariables = {
            PATH = "${emacsPackage}/bin:${config.home.homeDirectory}/.nix-profile/bin:/usr/local/bin:/usr/bin:/bin";
          };
        };
      };

      home.persistence."${self.persist}" = {
        directories = [
          ".config/emacs"
          ".cache/emacs"
          ".local/cache/emacs"
        ];
      };
    };
}
