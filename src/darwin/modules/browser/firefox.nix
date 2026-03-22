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
  name = "firefox";

  group = "browser";
  input = "darwin";

  on = {
    darwin.home = config: {
      nx.homebrew.casks = [ "firefox" ];
    };
  };
}
