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
    home =
      config:
      let
        isNiriEnabled = self.isLinux && (self.linux.isModuleEnabled "desktop.niri");
      in
      {
        home.packages = with pkgs; [
          ente-desktop
        ];

        nx.linux.desktop.niri.autostartPrograms = lib.mkIf isNiriEnabled [ "ente-desktop" ];

        programs.niri = lib.mkIf isNiriEnabled {
          settings = {
            binds = with config.lib.niri.actions; {
              "Mod+Ctrl+Alt+8" = {
                action = spawn-sh "niri-scratchpad --app-id ente --all-windows --spawn ente-desktop";
                hotkey-overlay.title = "Apps:Ente";
              };
            };

            window-rules = [
              {
                matches = [
                  {
                    app-id = "ente";
                  }
                ];
                open-on-workspace = "scratch";
                open-floating = true;
                open-focused = false;
                block-out-from = "screencast";
              }
            ];
          };
        };

        home.persistence."${self.persist.home}" = {
          directories = [
            ".config/ente"
          ];
        };
      };
  };
}
