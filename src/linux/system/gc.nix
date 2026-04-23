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
  name = "gc";

  group = "system";
  input = "linux";

  disableOnVM = true;

  settings = {
    useNH = true;
  };

  module = {
    linux.system = config: {
      programs.nh = lib.mkIf self.settings.useNH {
        enable = true;
        clean.enable = true;
        clean.extraArgs = "--keep-since 21d --keep 10";
      };

      nix = lib.mkIf (!self.settings.useNH) {
        gc = {
          automatic = true;
          dates = "19:00";
          options = "--delete-older-than 30d";
          persistent = true;
          randomizedDelaySec = "15min";
        };
      };
    };
  };
}
