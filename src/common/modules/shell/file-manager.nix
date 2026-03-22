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
  name = "file-manager";

  group = "shell";
  input = "common";

  on = {
    home = config: {
      home = {
        packages = with pkgs; [
          mc
          ranger
        ];
      };

      home.persistence."${self.persist.home}" = {
        directories = [
          ".config/ranger"
          ".local/share/ranger"
        ];
      };
    };
  };
}
