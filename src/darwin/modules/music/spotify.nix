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
    darwin.enabled = config: {
      nx.homebrew.casks = [ "spotify" ];
    };
  };
}
