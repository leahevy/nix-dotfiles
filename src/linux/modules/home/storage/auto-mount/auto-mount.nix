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
  name = "auto-mount";

  assertions = [
    {
      assertion = (self.host.isModuleEnabled or (x: false)) "storage.auto-mount";
      message = "Home storage.auto-mount requires system storage.auto-mount to be enabled!";
    }
  ];

  configuration =
    context@{ config, options, ... }:
    {
      services.udiskie = {
        enable = true;
        automount = true;
        notify = true;
        tray = "never";
        settings = {
          device_config = [
            {
              is_external = true;
              automount = true;
            }
            {
              is_external = false;
              ignore = true;
            }
          ];
        };
      };

      home.packages = with pkgs; [
        gvfs
      ];
    };
}
