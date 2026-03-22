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
  name = "rust-programs";

  group = "shell";
  input = "common";

  on = {
    home = config: {
      home.packages = with pkgs; [
        bat
        fd
        ripgrep
      ];

      home.shellAliases = {
        cat = "bat";
      };
    };
  };
}
