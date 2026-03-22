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

  on = {
    darwin.home = config: {
      nx.homebrew.casks = [ "docker-desktop" ];
    };
  };
}
