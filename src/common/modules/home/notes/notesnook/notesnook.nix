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
  name = "notesnook";

  group = "notes";
  input = "common";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    let
      isNiriEnabled = self.isLinux && (self.linux.isModuleEnabled "desktop.niri");
    in
    {
      home.packages = with pkgs; [
        notesnook
      ];

      programs.niri = lib.mkIf isNiriEnabled {
        settings = {
          binds = with config.lib.niri.actions; {
            "Mod+Ctrl+Alt+J" = {
              action = spawn-sh "niri-scratchpad --app-id Notesnook --all-windows --spawn notesnook";
              hotkey-overlay.title = "Apps:Notes app";
            };
          };

          window-rules = [
            {
              matches = [
                {
                  app-id = "Notesnook";
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

      home.persistence."${self.persist}" = {
        directories = [
          ".config/Notesnook"
        ];
      };
    };
}
