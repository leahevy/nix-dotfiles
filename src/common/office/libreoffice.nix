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
  name = "libreoffice";

  group = "office";
  input = "common";

  module = {
    enabled = config: {
      nx.preferences.desktop.programs.officeSuite = {
        name = "libreoffice";
        package = if self.isLinux then pkgs.libreoffice else null;
        openCommand = [ "libreoffice" ];
        openFileCommand = path: [
          "libreoffice"
          path
        ];
        desktopFile = "libreoffice-startcenter.desktop";
      };
    };

    linux.home = config: {
      home.packages = [ pkgs.libreoffice ];

      home.persistence."${self.persist}" = {
        directories = [ ".config/libreoffice" ];
      };
    };

    darwin.enabled = config: {
      nx.homebrew.casks = [ "libreoffice" ];
    };
  };
}
