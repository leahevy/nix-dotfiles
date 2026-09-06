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
    linux.home = config: {
      services.flatpak.packages = [ "io.github.dweymouth.supersonic" ];
    };
  };
}
