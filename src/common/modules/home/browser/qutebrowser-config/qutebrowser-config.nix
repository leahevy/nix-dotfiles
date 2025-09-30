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
  name = "qutebrowser-config";

  configuration =
    context@{ config, options, ... }:
    let
      isNiriEnabled = self.isLinux && (self.linux.isModuleEnabled "desktop.niri");
    in
    {
      programs.qutebrowser = {
        enable = true;
        package = lib.mkDefault null;
        extraConfig = ''
          import os
          import glob

          init_dir = os.path.expanduser("~/.config/qutebrowser-init")
          if os.path.exists(init_dir):
              for config_file in sorted(glob.glob(os.path.join(init_dir, "*.py"))):
                  config.source(config_file)
        '';
      };

      home.persistence."${self.persist}" = {
        directories = [
          ".config/qutebrowser"
          ".local/share/qutebrowser"
          ".cache/qutebrowser"
        ];
      };

      home.sessionVariables = {
        BROWSER = "qutebrowser";
      };

      programs.niri = lib.mkIf isNiriEnabled {
        settings = {
          binds = with config.lib.niri.actions; {
            "Ctrl+Mod+Alt+N" = {
              action = spawn-sh "qutebrowser";
              hotkey-overlay.title = "Apps:Browser";
            };
          };
        };
      };
    };
}
