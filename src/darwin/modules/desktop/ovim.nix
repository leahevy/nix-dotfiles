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
  name = "ovim";

  group = "desktop";
  input = "darwin";

  on = {
    darwin.home = config: {
      nx.homebrew.taps = [ "tonisives/tap" ];
      nx.homebrew.casks = [ "ovim" ];
    };
  };
}
