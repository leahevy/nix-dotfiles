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
  name = "bash";

  group = "shell";
  input = "common";

  module = {
    home = config: {
      programs = {
        nix-index.enableBashIntegration = true;
        bash = {
          enable = true;

          initExtra = ''
            if [[ -n ''${__SHELL_BOOTSTRAPPED:-} ]]; then
              return
            fi

            if [[ -f ${pkgs.fish}/bin/fish ]]; then
              if [[ -z ''${FISH_VERSION:-} && -z ''${BASH_EXECUTION_STRING} ]]; then
                shopt -q login_shell && LOGIN_OPTION="--login" || LOGIN_OPTION=""

                if ${pkgs.fish}/bin/fish $LOGIN_OPTION --command 'exit 0' >/dev/null 2>&1; then
                  __SHELL_BOOTSTRAPPED=1 exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
                fi
              fi
            fi

            if [[ -n ''${BASH_VERSION:-} && ''${BASH:-} != "${pkgs.bash}/bin/bash" ]]; then
              __SHELL_BOOTSTRAPPED=1 exec ${pkgs.bash}/bin/bash $LOGIN_OPTION
            fi
          '';
        };

      };

      home.persistence."${self.persist}" = {
        files = [
          # Already included in impermanence.nix
          # ".bash_history"
        ];
      };
    };
  };
}
