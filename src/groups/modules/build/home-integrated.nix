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
      core = [
        "programs"
        "utils"
        "tokens"
        "sops"
        "path"
        "preferences"
        "homebrew"
        "profile"
      ];
      desktop = [
        "desktop"
        "terminal"
      ];
      system = [ "dummy-files" ] ++ (if self.host.impermanence or false then [ "impermanence" ] else [ ]);
      theme = [ "theme-home" ];
    };
  };
}
