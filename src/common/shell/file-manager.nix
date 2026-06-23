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
  name = "file-manager";

  group = "shell";
  input = "common";

  module = {
    home = config: {
      home = {
        packages = with pkgs; [
          mc
          ranger
        ];
      };

      home.persistence."${self.persist}" = {
        directories = [
          ".config/ranger"
          ".local/share/ranger"
        ];
      };
    };
  };
}
