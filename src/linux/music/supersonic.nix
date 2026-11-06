args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
{
  name = "supersonic";
  description = "Desktop client for Navidrome and OpenSubsonic servers";

  group = "music";
  input = "linux";

  submodules = lib.optionalAttrs self.isLinux {
    linux.software.flatpak = true;
  };

  module = {
    home = config: {
      home.persistence."${self.persist}" = {
        directories = [
          ".config/supersonic"
          ".cache/supersonic"
        ];
      };
    };

    integrated = config: {
      home.packages = [ pkgs.supersonic ];
    };

    standalone = config: {
      services.flatpak.packages = [ "io.github.dweymouth.supersonic" ];

      home.packages = [
        (pkgs.writeShellScriptBin "supersonic" ''
          exec ${pkgs.flatpak}/bin/flatpak run io.github.dweymouth.supersonic "$@"
        '')
      ];
    };

    ifEnabled.linux.desktop.niri.linux.enabled = config: {
      nx.linux.desktop.niri.autostartPrograms = [
        "supersonic"
      ];
    };

    ifEnabled.linux.desktop.niri.home = config: {
      programs.niri = {
        settings = {
          binds = with config.lib.niri.actions; {
            "Mod+Ctrl+Alt+T" = {
              action = spawn-sh "niri-scratchpad --app-id ${
                if self.user.isStandalone then "io.github.supersonic-app.supersonic" else "Supersonic"
              } --all-windows --spawn supersonic";
              hotkey-overlay.title = "Apps:Supersonic";
            };
          };

          window-rules = [
            {
              matches = [
                {
                  app-id = if self.user.isStandalone then "io.github.supersonic-app.supersonic" else "Supersonic";
                }
              ];
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
