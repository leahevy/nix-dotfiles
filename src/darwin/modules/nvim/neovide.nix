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
  name = "neovide";

  group = "nvim";
  input = "darwin";

  on = {
    darwin.home = config: {
      nx.homebrew.brews = [ "neovide" ];
    };
  };
}
