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
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    let
      isNiriEnabled = self.isModuleEnabled "desktop.niri";
      appLauncher = config.nx.preferences.desktop.programs.appLauncher;
      appLauncherDmenuSimple = lib.escapeShellArgs (appLauncher.openCommand ++ appLauncher.dmenuArgs);
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

      programs.niri = lib.mkIf isNiriEnabled {
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
}
