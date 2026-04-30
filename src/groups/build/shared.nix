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
  name = "shared";
  description = "Shared build modules";

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
        "nx-config"
        "homebrew"
        "profile"
        "man"
        "commandline"
      ];
      desktop = [
        "desktop"
        "terminal"
      ];
      system = [ "dummy-files" ];
      theme = [ "theme-home" ];
      inputs = (if self.user.settings.hasRemoteCommand or false then [ "nixos-anywhere" ] else [ ]);
    };
  };
}
