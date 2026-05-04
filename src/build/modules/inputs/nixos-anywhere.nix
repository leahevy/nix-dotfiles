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
  group = "inputs";
  input = "build";

  disableOnVirtual = true;

  module = {
    home = config: {
      home.packages = [
        self.inputs.nixos-anywhere.packages.${pkgs.system}.default
      ];
    };
  };
}
