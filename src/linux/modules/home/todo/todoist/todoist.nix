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
  name = "todoist";

  unfree = [ "todoist-electron" ];

  configuration =
    context@{ config, options, ... }:
    let
      isNiriEnabled = self.isLinux && (self.linux.isModuleEnabled "desktop.niri");
    in
    {
      home.packages = with pkgs-unstable; [
        todoist-electron
      ];

      home.persistence."${self.persist}" = {
        directories = [ ".config/Todoist" ];
      };

      programs.niri = lib.mkIf isNiriEnabled {
        settings = {
          binds = with config.lib.niri.actions; {
            "Ctrl+Mod+Alt+Y" = {
              action = spawn-sh "niri-scratchpad --app-id Todoist --spawn todoist-electron";
              hotkey-overlay.title = "Apps:Todo app";
            };
          };

          window-rules = [
            {
              matches = [ { app-id = "Todoist"; } ];
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
