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
  name = "zsh";

  configuration =
    context@{ config, options, ... }:
    {
      programs = {
        nix-index.enableZshIntegration = true;
        zsh = {
          enable = true;

          initContent = ''
            PROMPT='%F{green}%*%f %F{blue}%~%f $ '

            if [[ -f ${pkgs.fish}/bin/fish ]]; then
              if [[ $(${pkgs.procps}/bin/ps -o command= -p "$PPID" | awk '{print $1}') != "fish" ]]; then
                [[ -o login ]] && LOGIN_OPTION="--login" || LOGIN_OPTION=""
                exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
              fi
            fi
          '';
        };

      };

      home.persistence."${self.persist}" = {
        files = [
          ".zsh_history"
        ];
        directories = [
          ".config/zsh"
        ];
      };
    };
}
