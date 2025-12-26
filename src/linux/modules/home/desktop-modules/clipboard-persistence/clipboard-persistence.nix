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
  name = "clipboard-persistence";

  group = "desktop-modules";
  input = "linux";
  namespace = "home";

  assertions = [
    {
      assertion = self.isModuleEnabled "desktop-modules.fuzzel";
      message = "Fuzzel is required for clipboard-persistence";
    }
  ];

  configuration =
    context@{ config, ... }:
    let
      clipmanPackage = pkgs.clipman;
      wlClipboardPackage = pkgs.wl-clipboard;
    in
    lib.mkMerge [
      {
        home.packages = [
          wlClipboardPackage
        ];

        services.clipman = {
          enable = true;
          package = clipmanPackage;
        };

        systemd.user.services."clipman" = {
          Service = {
            ExecStart = lib.mkForce "${wlClipboardPackage}/bin/wl-paste -t text --watch ${clipmanPackage}/bin/clipman store --no-persist";
          };
        };
      }

      (lib.mkIf (self.isModuleEnabled "desktop.niri") {
        programs.niri.settings.binds."Mod+B" = with config.lib.niri.actions; {
          action = spawn-sh "${clipmanPackage}/bin/clipman pick --tool=CUSTOM --tool-args=\"fuzzel -d\"";
          hotkey-overlay.title = "Clipboard:Clipboard manager";
        };
      })
    ];
}
