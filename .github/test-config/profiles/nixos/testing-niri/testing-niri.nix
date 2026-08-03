{
  lib,
  pkgs,
  variables,
  helpers,
  defs,
  self,
  ...
}:
{
  config.host = {
    hostname = "testing-niri";

    mainUser = "testuser";

    deploymentMode = "develop";

    addBaseGroup = true;

    sopsPublicKey = "@SOPS_AGE_PUBLIC_KEY@";

    displays = {
      main = "Virtual-1";
    };

    modules = {
      linux = {
        notifications = {
          pushover = true;
        };
        virtualisation = {
          docker = true;
        };
        desktop-modules = {
          swaybg = {
            additionalWallpaperDirectories = [
              "~/wallpaper"
            ];
          };
          nwg-wrapper = {
            usedShell = "fish";
          };
          waybar = {
            addDataDisk = true;
          };
          bongocat = {
            useKeydVirtual = true;
          };
        };
      };
    };

    settings = {
      system = {
        desktop = "niri";
      };
    };

    impermanence = true;
  };
}
