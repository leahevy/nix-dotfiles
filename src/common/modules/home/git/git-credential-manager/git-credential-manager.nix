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
      home.packages = with pkgs; [
        git-credential-manager
        pass
      ];

      programs.git = {
        extraConfig.credential = {
          helper = "manager";
          credentialStore = "gpg";
        };
      };

      home.file."${config.xdg.configHome}/fish-init/60-check-pass.fish".text = (
        if self.user.gpg != null then
          ''
            if ! test -d "${self.user.home}/.password-store"; or test -z "(ls -A "${self.user.home}/.password-store" 2>/dev/null)"
              echo "Init pass for gpg key: ${self.user.gpg}"
              pass init ${self.user.gpg}
            end
          ''
        else
          ""
      );

      home.persistence."${self.persist}" = {
        directories = [
          ".password-store"
        ];
      };
    };
}
