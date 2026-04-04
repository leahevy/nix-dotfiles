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
  name = "signal";

  group = "chat";
  input = "linux";

  on = {
    linux.home = config: {
      home.packages = with pkgs; [
        signal-desktop
      ];

      home.persistence."${self.persist}" = {
        directories = [
          ".config/Signal"
        ];
      };
    };
  };
}
