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

  on = {
    linux.enabled = config: {
      nx.linux.desktop.niri.autostartPrograms = lib.mkIf (self.linux.isModuleEnabled "desktop.niri") [
        "nstv-term"
      ];
    };

    home =
      config:
      let
        terminal = config.nx.preferences.desktop.programs.additionalTerminal;
        terminalRunWithClass =
          class: cmd:
          lib.escapeShellArgs (
            helpers.runWithAbsolutePath config terminal (terminal.openRunWithClass class) cmd
          );
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
            exec ${terminalRunWithClass "org.nx.nix-search-tv" "nstv"}
          '';
          executable = true;
        };
      };

    moduleEnabled.linux.desktop.niri.home = config: {
      programs.niri = {
        settings = {
          binds = with config.lib.niri.actions; {
            "Mod+Ctrl+Alt+H" = {
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
  };
}
