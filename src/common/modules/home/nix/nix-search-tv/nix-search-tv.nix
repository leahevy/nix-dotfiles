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
  name = "nix-search-tv";

  group = "nix";
  input = "common";
  namespace = "home";

  defaults = {
    terminal = "ghostty";
  };

  configuration =
    context@{ config, options, ... }:
    let
      isNiriEnabled = self.isLinux && (self.linux.isModuleEnabled "desktop.niri");
    in
    {
      home.persistence."${self.persist}" = {
        directories = [
          ".cache/nix-search-tv"
        ];
      };

      home.packages = with pkgs; [
        nix-search-tv
        fzf
      ];

      home.file.".local/bin/nstv" = {
        text = ''
          #!/usr/bin/env bash
          nix-search-tv print | fzf --preview 'nix-search-tv preview {}' --scheme history
        '';
        executable = true;
      };

      home.file.".local/bin/nstv-term" = {
        text = ''
          #!/usr/bin/env bash
          exec ${self.settings.terminal} --class=org.nx.nix-search-tv -e nstv
        '';
        executable = true;
      };

      programs.niri = lib.mkIf isNiriEnabled {
        settings = {
          binds = with config.lib.niri.actions; {
            "Ctrl+Mod+Alt+H" = {
              action = spawn-sh "niri-scratchpad --app-id org.nx.nix-search-tv --all-windows --spawn nstv-term";
              hotkey-overlay.title = "System:Search Nix Packages";
            };
          };

          window-rules = [
            {
              matches = [ { app-id = "org.nx.nix-search-tv"; } ];
              min-width = 800;
              min-height = 800;
              open-on-workspace = "scratch";
              open-floating = true;
              open-focused = false;
            }
          ];
        };
      };
    };
}
