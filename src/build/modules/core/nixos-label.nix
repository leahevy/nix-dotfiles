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
  name = "nixos-label";
  group = "core";
  input = "build";

  module = {
    linux.system = config: {
      system.nixos.label =
        let
          labelFile = self.config.rootPath ".label";
        in
        lib.mkIf (builtins.pathExists labelFile) (
          builtins.head (lib.splitString "\n" (builtins.readFile labelFile))
        );
    };
  };
}
