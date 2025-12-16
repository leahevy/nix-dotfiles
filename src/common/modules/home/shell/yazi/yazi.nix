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
  name = "yazi";

  group = "shell";
  input = "common";
  namespace = "home";

  settings = {
    baseSettings = {
      mgr = {
        ratio = [
          1
          2
          4
        ];
        show_hidden = true;
        show_symlink = true;
        sort_by = "mtime";
        sort_reverse = true;
        sort_dir_first = false;
        scrolloff = 5;
      };
      preview = {
        wrap = "yes";
        tab_size = 2;
        max_width = 1920;
        max_height = 1080;
      };
      tasks = {
        micro_workers = 10;
        macro_workers = 25;
        image_alloc = 536870912;
      };
      input = {
        cursor_blink = true;
      };
    };
    additionalSettings = { };
  };

  configuration =
    context@{ config, options, ... }:
    let
      isNiriEnabled = self.isLinux && (self.linux.isModuleEnabled "desktop.niri");
    in
    {
      programs.yazi = {
        enable = true;
        enableBashIntegration = true;
        enableFishIntegration = true;
        enableZshIntegration = true;

        settings = lib.recursiveUpdate self.settings.baseSettings self.settings.additionalSettings;
      };

      home.file.".local/bin/nx-yazi" = {
        text = ''
          #!/usr/bin/env bash
          yazi
        '';
        executable = true;
      };

      home.file.".local/bin/nx-yazi-term" = {
        text = ''
          #!/usr/bin/env bash
          exec ${self.user.settings.terminal} --class=org.nx.yazi -e nx-yazi
        '';
        executable = true;
      };

      programs.niri = lib.mkIf isNiriEnabled {
        settings = {
          binds = with config.lib.niri.actions; {
            "Mod+Ctrl+Alt+M" = {
              action = spawn-sh "niri-scratchpad --app-id org.nx.yazi --all-windows --spawn nx-yazi-term";
              hotkey-overlay.title = "Apps:File manager";
            };
          };

          window-rules = [
            {
              matches = [ { app-id = "org.nx.yazi"; } ];
              min-width = 1200;
              min-height = 800;
              open-on-workspace = "scratch";
              open-floating = true;
              open-focused = false;
            }
          ];
        };
      };

      home.persistence."${self.persist}" = {
        directories = [
          ".local/state/yazi"
        ];
      };
    };
}
