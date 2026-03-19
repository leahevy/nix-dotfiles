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

  configuration =
    context@{ config, ... }:
    let
      clipmanPackage = pkgs.clipman;
      wlClipboardPackage = pkgs.wl-clipboard;
      appLauncher = config.nx.preferences.desktop.programs.appLauncher;
      appLauncherDmenuSimple = lib.escapeShellArgs (
        (helpers.runWithAbsolutePath config appLauncher appLauncher.openCommand [ ])
        ++ appLauncher.dmenuArgs
      );
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
          action = spawn-sh "${clipmanPackage}/bin/clipman pick --tool=CUSTOM --tool-args=\"${appLauncherDmenuSimple}\"";
          hotkey-overlay.title = "Clipboard:Clipboard manager";
        };
      })
    ];
}
