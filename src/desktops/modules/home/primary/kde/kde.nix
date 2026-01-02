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
  name = "kde";

  group = "primary";
  input = "desktops";
  namespace = "home";

  settings = {
    name = "kde";

    preferences = {
      wallet = {
        package = pkgs.kdePackages.kwallet;
        additionalPackages = [
          pkgs.kdePackages.kwalletmanager
          pkgs.kwalletcli
        ];
      };
      systemSettings = {
        package = pkgs.kdePackages.systemsettings;
      };
      networkSettings = {
        package = pkgs.kdePackages.plasma-nm;
      };
      taskManager = {
        package = pkgs.kdePackages.plasma-systemmonitor;
      };
    };
  };
}
