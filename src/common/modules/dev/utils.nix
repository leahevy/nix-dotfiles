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
  name = "utils";

  group = "dev";
  input = "common";

  on = {
    home = config: {
      home.packages = with pkgs; [
        socat
      ];
    };
  };
}
