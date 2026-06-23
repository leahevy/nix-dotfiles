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
  name = "go-programs";

  group = "shell";
  input = "common";

  module = {
    home = config: {
      home.packages = with pkgs; [
        fzf
      ];
    };
  };
}
