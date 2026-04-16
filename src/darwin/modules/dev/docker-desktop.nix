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
  name = "docker-desktop";

  group = "dev";
  input = "darwin";

  module = {
    darwin.enabled = config: {
      nx.homebrew.casks = [ "docker-desktop" ];
    };
  };
}
