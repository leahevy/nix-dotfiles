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
  name = "go-programs";

  group = "shell";
  input = "common";

  on = {
    home = config: {
      home.packages = with pkgs; [
        fzf
      ];
    };
  };
}
