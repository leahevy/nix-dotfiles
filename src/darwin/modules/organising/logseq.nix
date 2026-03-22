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
  name = "logseq";

  group = "organising";
  input = "darwin";

  on = {
    darwin.home = config: {
      nx.homebrew.casks = [ "logseq" ];
    };
  };
}
