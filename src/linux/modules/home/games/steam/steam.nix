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
  name = "steam";

  configuration =
    context@{ config, options, ... }:
    let
      isNiriEnabled = self.isLinux && self.linux.isModuleEnabled "desktop.niri";
    in
    {
      home.packages = with pkgs-unstable; [
        steam
      ];

      programs.niri = lib.mkIf isNiriEnabled {
        settings = {
          window-rules = [
            {
              matches = [
                {
                  app-id = "steam";
                  title = "^notificationtoasts_\\d+_desktop$";
                }
              ];
              default-floating-position = {
                x = 10;
                y = 10;
                relative-to = "bottom-right";
              };
            }
          ];
        };
      };
    };
}
