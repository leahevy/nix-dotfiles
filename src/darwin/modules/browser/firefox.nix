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

  module = {
    darwin.enabled = config: {
      nx.homebrew.casks = [ "firefox" ];
    };
  };
}
