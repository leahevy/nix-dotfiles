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

  group = "dev";
  input = "common";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      home.packages = with pkgs; [
        typescript
        typescript-language-server
      ];
    };
}
