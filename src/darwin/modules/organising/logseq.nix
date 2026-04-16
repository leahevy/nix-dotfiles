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

  module = {
    darwin.enabled = config: {
      nx.homebrew.casks = [ "logseq" ];
    };
  };
}
