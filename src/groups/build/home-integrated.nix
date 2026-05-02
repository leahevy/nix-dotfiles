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
  name = "home-integrated";
  description = "Build modules for NixOS integrated home-manager configuration";

  group = "build";
  input = "groups";

  submodules = {
    build = {
      system = (if self.host.impermanence or false then [ "impermanence" ] else [ ]) ++ [
        "home-manager"
      ];
    };
  };
}
