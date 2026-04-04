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
  name = "vscodium";

  group = "dev";
  input = "common";

  on = {
    home = config: {
      home.packages = with pkgs; [
        vscodium
      ];

      home.persistence."${self.persist}" = {
        directories = [
          ".config/VSCodium"
          ".vscode-oss"
          ".cache/Microsoft"
        ];
      };
    };
  };
}
