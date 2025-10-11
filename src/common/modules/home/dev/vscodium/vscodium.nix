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

  configuration =
    context@{ config, options, ... }:
    {
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
}
