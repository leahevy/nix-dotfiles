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
  name = "web-devicons";

  group = "nvim-modules";
  input = "common";

  module = {
    home = config: {
      programs.nixvim.plugins.web-devicons = {
        enable = true;
      };
    };
  };
}
