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
  name = "spotify";

  group = "music";
  input = "darwin";

  module = {
    darwin.enabled = config: {
      nx.homebrew.casks = [ "spotify" ];
    };
  };
}
