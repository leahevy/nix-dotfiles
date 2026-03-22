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

  on = {
    home = config: {
      home.packages = with pkgs; [
        typescript
        typescript-language-server
      ];
    };
  };
}
