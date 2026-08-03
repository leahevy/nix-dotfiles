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

  group = "desktop-modules";
  input = "linux";

  module = {
    home =
      config:
      let
        clipmanPackage = pkgs.clipman;
        wlClipboardPackage = pkgs.wl-clipboard;
        dmenu =
          helpers.requirePreferenceProgram config "dmenu"
            "the clipboard picker requires a dmenu style picker, enable linux.desktop-modules.fuzzel";
        dmenuCmdSimple = lib.escapeShellArgs (
          (helpers.runWithAbsolutePath config dmenu dmenu.openCommand [ ]) ++ dmenu.dmenuArgs
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
            action = spawn-sh "${clipmanPackage}/bin/clipman pick --tool=CUSTOM --tool-args=\"${dmenuCmdSimple}\"";
            hotkey-overlay.title = "Clipboard:Clipboard manager";
          };
        })
      ];
  };
}
