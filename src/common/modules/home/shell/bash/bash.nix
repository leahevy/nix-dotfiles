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
    {
      programs = {
        nix-index.enableBashIntegration = true;
        bash = {
          enable = true;

          initExtra = ''
            if [[ -f ${pkgs.fish}/bin/fish ]]; then
              if [[ $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]; then
                shopt -q login_shell && LOGIN_OPTION="--login" || LOGIN_OPTION=""
                exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
              fi
            fi
          '';
        };

      };

      home.persistence."${self.persist}" = {
        files = [
          ".bash_history"
        ];
      };
    };
}
