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
  name = "bemoji";

  group = "desktop-modules";
  input = "linux";

  module = {
    ifEnabled.linux.desktop.niri.home = config: {
      programs.niri = {
        settings = {
          binds = with config.lib.niri.actions; {
            "Mod+Period" = {
              action = spawn-sh "bemoji";
              hotkey-overlay.title = "Utils:Emoji picker";
            };
          };
        };
      };
    };

    home =
      config:
      let
        dmenu =
          helpers.requirePreferenceProgram config "dmenu"
            "bemoji requires a dmenu style picker, enable linux.desktop-modules.fuzzel";
        dmenuCmdSimple = lib.escapeShellArgs (
          (helpers.runWithAbsolutePath config dmenu dmenu.openCommand [ ]) ++ dmenu.dmenuArgs
        );
      in
      {
        home.packages = [ pkgs.bemoji ];

        home.sessionVariables = {
          BEMOJI_PICKER_CMD = dmenuCmdSimple;
        };

        home.persistence."${self.persist}" = {
          directories = [
            ".local/share/bemoji"
          ];
        };
      };
  };
}
