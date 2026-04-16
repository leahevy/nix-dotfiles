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
  name = "gimp";

  group = "graphics";
  input = "darwin";

  module = {
    darwin.enabled = config: {
      nx.homebrew.casks = [ "gimp" ];
    };
  };
}
