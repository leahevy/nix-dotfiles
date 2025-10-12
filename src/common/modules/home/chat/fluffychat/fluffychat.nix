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
  name = "fluffychat";

  configuration =
    context@{ config, options, ... }:
    let
      isNiriEnabled = self.isLinux && (self.linux.isModuleEnabled "desktop.niri");
    in
    {
      home.packages = with pkgs-unstable; [
        fluffychat
      ];

      home.persistence."${self.persist}" = {
        directories = [
          ".local/share/chat.fluffy.fluffychat"
        ];
      };

      programs.niri = lib.mkIf isNiriEnabled {
        settings = {
          binds = with config.lib.niri.actions; {
            "Ctrl+Mod+Alt+P" = {
              action = spawn-sh "niri-scratchpad --app-id fluffychat --all-windows --spawn fluffychat";
              hotkey-overlay.title = "Apps:Matrix chat";
            };
          };

          window-rules = [
            {
              matches = [
                {
                  app-id = "fluffychat";
                }
              ];
              min-width = 1500;
              min-height = 800;
              open-on-workspace = "scratch";
              open-floating = true;
              open-focused = false;
              block-out-from = "screencast";
            }
          ];
        };
      };
    };
}
