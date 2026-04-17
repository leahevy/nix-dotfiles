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
  name = "better-display";

  group = "desktop";
  input = "darwin";

  module = {
    darwin.enabled = config: {
      nx.homebrew.casks = [ "betterdisplay" ];
    };
  };
}
