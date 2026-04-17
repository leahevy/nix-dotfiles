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
  name = "spotify";

  group = "music";
  input = "darwin";

  module = {
    darwin.enabled = config: {
      nx.homebrew.casks = [ "spotify" ];
    };
  };
}
