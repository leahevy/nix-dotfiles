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

  on = {
    darwin.home = config: {
      nx.homebrew.casks = [ "spotify" ];
    };
  };
}
