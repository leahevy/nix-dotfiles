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
  name = "vscodium";

  group = "dev";
  input = "common";

  requirePlatforms = [ "linux" ];

  module = {
    enabled = config: {
      nx.common.git.git.globalIgnores = [
        ".vscode/"
      ];
    };

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
