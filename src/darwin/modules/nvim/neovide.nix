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

  module = {
    darwin.enabled = config: {
      nx.homebrew.brews = [ "neovide" ];
    };
  };
}
