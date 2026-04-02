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
  name = "vscode";

  group = "dev";
  input = "darwin";

  on = {
    darwin.enabled = config: {
      nx.homebrew.casks = [ "visual-studio-code" ];
    };
  };
}
