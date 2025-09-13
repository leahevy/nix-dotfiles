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
  name = "typescript-lsp";

  configuration =
    context@{ config, options, ... }:
    {
      home.packages = with pkgs; [
        typescript
        typescript-language-server
      ];
    };
}
