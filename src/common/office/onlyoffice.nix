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
  name = "onlyoffice";

  group = "office";
  input = "common";

  module = {
    enabled = config: {
      nx.preferences.desktop.programs.officeSuite = {
        name = "onlyoffice";
        package = if self.isLinux then pkgs.onlyoffice-desktopeditors else null;
        openCommand = [ "onlyoffice-desktopeditors" ];
        openFileCommand = path: [
          "onlyoffice-desktopeditors"
          path
        ];
        desktopFile = "onlyoffice-desktopeditors.desktop";
      };
    };

    linux.home = config: {
      home.packages = [ pkgs.onlyoffice-desktopeditors ];

      home.persistence."${self.persist}" = {
        directories = [
          ".config/onlyoffice"
          ".local/share/onlyoffice"
        ];
      };
    };

    darwin.enabled = config: {
      nx.homebrew.casks = [ "onlyoffice" ];
    };
  };
}
