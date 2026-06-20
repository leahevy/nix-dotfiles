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
  name = "docker-desktop";

  group = "dev";
  input = "darwin";

  module = {
    darwin.enabled = config: {
      nx.homebrew.casks = [ "docker-desktop" ];
    };
  };
}
