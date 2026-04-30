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
  name = "nixos-anywhere";
  group = "dev";
  input = "common";

  disableOnVM = true;

  module = {
    home = config: {
      home.packages = [
        self.inputs.nixos-anywhere.packages.${pkgs.system}.default
      ];
    };
  };
}
