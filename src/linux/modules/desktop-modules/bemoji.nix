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
  name = "bemoji";

  group = "desktop-modules";
  input = "linux";

  on = {
    moduleEnabled.linux.desktop.niri.home = config: {
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
        appLauncher = config.nx.preferences.desktop.programs.appLauncher;
        appLauncherDmenuSimple = lib.escapeShellArgs (
          (helpers.runWithAbsolutePath config appLauncher appLauncher.openCommand [ ])
          ++ appLauncher.dmenuArgs
        );
      in
      {
        home.packages = [ pkgs.bemoji ];

        home.sessionVariables = {
          BEMOJI_PICKER_CMD = appLauncherDmenuSimple;
        };

        home.persistence."${self.persist}" = {
          directories = [
            ".local/share/bemoji"
          ];
        };
      };
  };
}
