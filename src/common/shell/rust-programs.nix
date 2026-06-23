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
  name = "rust-programs";

  group = "shell";
  input = "common";

  module = {
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
