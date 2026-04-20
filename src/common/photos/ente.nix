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

  requiredPlatforms = [ "linux" ];

  module = {
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

    home = config: {
      home.packages = with pkgs; [
        ente-desktop
      ];

      home.persistence."${self.persist}" = {
        directories = [
          ".config/ente"
        ];
      };
    };

    ifEnabled.linux.desktop.niri.home = config: {
      programs.niri = {
        settings.binds = with config.lib.niri.actions; {
          "Mod+Ctrl+Alt+8" = {
            action = spawn-sh "niri-scratchpad --title 'Ente Photos' --all-windows --spawn ente-desktop";
            hotkey-overlay.title = "Apps:Ente";
          };
        };
      };
    };
  };
}
