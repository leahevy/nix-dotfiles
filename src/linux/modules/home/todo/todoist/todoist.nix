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

  group = "todo";
  input = "linux";
  namespace = "home";

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
            "Mod+Ctrl+Alt+Y" = {
              action = spawn-sh "niri-scratchpad --app-id Todoist --all-windows --spawn todoist-electron";
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
