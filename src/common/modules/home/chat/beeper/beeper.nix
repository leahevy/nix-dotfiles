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
  name = "beeper";

  unfree = [ "beeper" ];

  defaults = {
    waylandQuirks = false;
  };

  configuration =
    context@{ config, options, ... }:
    let
      isNiriEnabled = self.isLinux && (self.linux.isModuleEnabled "desktop.niri");
      beeperWrapped =
        if self.settings.waylandQuirks then
          (pkgs-unstable.symlinkJoin {
            name = "beeper-wrapped";
            paths = [ pkgs-unstable.beeper ];
            buildInputs = [ pkgs-unstable.makeWrapper ];
            postBuild = ''
              wrapProgram $out/bin/beeper \
                --add-flags "--disable-gpu-compositing"

              rm -f $out/share/applications/beepertexts.desktop
              mkdir -p $out/share/applications
              substitute ${pkgs-unstable.beeper}/share/applications/beepertexts.desktop \
                $out/share/applications/beepertexts.desktop \
                --replace "Exec=beeper" "Exec=$out/bin/beeper"
            '';
          })
        else
          pkgs-unstable.beeper;
    in
    {
      home.packages = [
        beeperWrapped
      ];

      home.persistence."${self.persist}" = {
        directories = [ ".config/BeeperTexts" ];
      };

      programs.niri = lib.mkIf isNiriEnabled {
        settings = {
          binds = with config.lib.niri.actions; {
            "Ctrl+Mod+Alt+I" = {
              action = spawn-sh "niri-scratchpad --app-id BeeperTexts --spawn beeper";
              hotkey-overlay.title = "Apps:Chat app";
            };
          };

          window-rules = [
            {
              matches = [ { app-id = "BeeperTexts"; } ];
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
