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
  name = "ente";

  group = "photos";
  input = "common";

  on = {
    linux.enabled = config: {
      nx.linux.desktop.niri.autostartPrograms = lib.mkIf (self.linux.isModuleEnabled "desktop.niri") [
        "ente-desktop"
      ];
      nx.linux.desktop.niri.lateWindowRules = lib.mkIf (self.linux.isModuleEnabled "desktop.niri") [
        {
          match = {
            app-id = "electron";
            title = "Ente Photos";
          };
          apply = {
            float = true;
            workspace = "scratch";
          };
        }
      ];
    };

    home =
      config:
      let
        isNiriEnabled = self.isLinux && (self.linux.isModuleEnabled "desktop.niri");
      in
      {
        home.packages = with pkgs; [
          ente-desktop
        ];

        programs.niri = lib.mkIf isNiriEnabled {
          settings.binds = with config.lib.niri.actions; {
            "Mod+Ctrl+Alt+8" = {
              action = spawn-sh "niri-scratchpad --title 'Ente Photos' --all-windows --spawn ente-desktop";
              hotkey-overlay.title = "Apps:Ente";
            };
          };
        };

        home.persistence."${self.persist}" = {
          directories = [
            ".config/ente"
          ];
        };
      };
  };
}
