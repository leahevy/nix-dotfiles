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
  name = "game-quirks";

  group = "games";
  input = "linux";

  description = "Hardcoded per-game quirks to get specific games running";

  options = {
    albionOnline = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
  };

  module = {
    ifEnabled.linux.desktop.niri.home =
      config:
      let
        cfg = config.nx.linux.games.game-quirks;
      in
      lib.mkMerge [
        (lib.mkIf cfg.albionOnline {
          programs.niri.settings.window-rules = [
            {
              matches = [ { app-id = "^Albion-Online$"; } ];
              open-floating = false;
              open-fullscreen = true;
            }
          ];
        })
      ];
  };
}
