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
  name = "vscode";

  group = "dev";
  input = "darwin";

  module = {
    darwin.enabled = config: {
      nx.homebrew.casks = [ "visual-studio-code" ];
    };
  };
}
