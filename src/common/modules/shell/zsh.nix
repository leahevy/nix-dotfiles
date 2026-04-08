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

  group = "shell";
  input = "common";

  on = {
    home = config: {
      programs = {
        nix-index.enableZshIntegration = true;
        zsh = {
          enable = true;

          initContent = ''
            PROMPT='%F{green}%*%f %F{blue}%~%f $ '

            if [[ -n ''${__SHELL_BOOTSTRAPPED:-} ]]; then
              return
            fi

            [[ -o login ]] && LOGIN_OPTION="--login" || LOGIN_OPTION=""

            if [[ -x ${pkgs.fish}/bin/fish && -z ''${FISH_VERSION:-} ]]; then
              if ${pkgs.fish}/bin/fish $LOGIN_OPTION --command 'exit 0' >/dev/null 2>&1; then
                __SHELL_BOOTSTRAPPED=1 exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
              fi
            fi

            if [[ -n ''${ZSH_VERSION:-} ]]; then
              if [[ ''${ZSH_NAME:-} != "zsh" || ''${ZSH_ARGZERO:-} != "${pkgs.zsh}/bin/zsh" ]]; then
                if [[ -x ${pkgs.zsh}/bin/zsh && ''${ZSH_ARGZERO:-} != "${pkgs.zsh}/bin/zsh" ]]; then
                  __SHELL_BOOTSTRAPPED=1 exec ${pkgs.zsh}/bin/zsh $LOGIN_OPTION
                fi
              fi
            fi
          '';
        };

      };

      home.persistence."${self.persist}" = {
        files = [
          # Already included in impermanence.nix
          # ".zsh_history"
        ];
        directories = [
          ".config/zsh"
        ];
      };
    };
  };
}
