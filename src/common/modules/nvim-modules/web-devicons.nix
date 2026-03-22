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
  name = "web-devicons";

  group = "nvim-modules";
  input = "common";

  on = {
    home = config: {
      programs.nixvim.plugins.web-devicons = {
        enable = true;
      };
    };
  };
}
