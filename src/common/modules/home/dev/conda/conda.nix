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
  name = "conda";

  defaults = {
    withPkgInstall = false;
  };

  configuration =
    context@{ config, options, ... }:
    {
      home.packages = lib.mkIf (self.isLinux && self.settings.withPkgInstall) (
        with pkgs;
        [
          conda
        ]
      );

      home.file."${config.xdg.configHome}/fish-init/60-conda.fish".text = ''
        if command -q conda
          conda init fish --user --quiet >/dev/null
        ${lib.optionalString self.isDarwin "else\n  echo 'Install conda on Mac with: brew install --cask miniconda'"}
        end
      '';

      home.persistence."${self.persist}" = lib.mkIf self.isLinux {
        directories = [
          ".conda"
        ];
        files = [
          ".condarc"
        ];
      };
    };
}
