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
  name = "logseq";

  group = "organising";
  input = "linux";

  on = {
    linux.enabled = config: {
      nx.linux.desktop.niri.autostartPrograms = lib.mkIf (self.isModuleEnabled "desktop.niri") [
        "logseq"
      ];
    };

    home =
      config:
      let
        isNiriEnabled = self.isLinux && (self.linux.isModuleEnabled "desktop.niri");
      in
      {
        home.packages = with pkgs; [
          logseq
        ];

        programs.niri = lib.mkIf isNiriEnabled {
          settings = {
            binds = with config.lib.niri.actions; {
              "Mod+Ctrl+Alt+J" = {
                action = spawn-sh "niri-scratchpad --app-id Logseq --all-windows --spawn logseq";
                hotkey-overlay.title = "Apps:Logseq";
              };
            };

            window-rules = [
              {
                matches = [
                  {
                    app-id = "Logseq";
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
            ".config/Logseq"
            ".logseq"
          ];
        };
      };
  };
}
