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
  name = "gpg";

  configuration =
    context@{ config, options, ... }:
    {
      services = {
        gpg-agent = {
          enable = true;
          pinentry.package = if self.isLinux then pkgs.pinentry-curses else pkgs.pinentry_mac;
          maxCacheTtl = 86400;
          maxCacheTtlSsh = 86400;
          defaultCacheTtl = 43200;
          defaultCacheTtlSsh = 43200;
        };
      };

      home = {
        packages =
          (if self.isLinux then with pkgs; [ pinentry ] else with pkgs; [ pinentry_mac ])
          ++ (with pkgs; [ gnupg ]);
      };

      home.file.".gnupg/common.conf" = {
        source = self.symlinkFile config "common.conf";
      };

      programs.gpg = {
        enable = true;

        settings =
          { }
          // (
            if self.user.gpg != null then
              {
                default-key = self.user.gpg;
              }
            else
              { }
          );
      };

      home.file."${config.xdg.configHome}/fish-init/20-gpg-tty.fish".text = ''
        export GPG_TTY=$(tty)
      '';

      home.persistence."${self.persist}" = {
        directories = [
          ".gnupg"
        ];
      };
    };
}
