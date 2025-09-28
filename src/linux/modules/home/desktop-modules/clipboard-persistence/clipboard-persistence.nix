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
  name = "clipboard-persistence";

  assertions = [
    {
      assertion = self.isModuleEnabled "desktop-modules.fuzzel";
      message = "Fuzzel is required for clipboard-persistence";
    }
  ];

  configuration =
    context@{ config, ... }:
    lib.mkMerge [
      {
        home.packages = with pkgs; [
          wl-clipboard
          clipman
        ];

        services.clipman.enable = true;
      }

      (lib.mkIf (self.isModuleEnabled "desktop.niri") {
        programs.niri.settings.binds."Mod+B" = with config.lib.niri.actions; {
          action = spawn-sh "${pkgs.clipman}/bin/clipman pick --tool=CUSTOM --tool-args=\"fuzzel -d\"";
          hotkey-overlay.title = "Clipboard:Clipboard manager";
        };
      })
    ];
}
