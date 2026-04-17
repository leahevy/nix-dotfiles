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
  name = "slack";

  group = "chat";
  input = "darwin";

  module = {
    darwin.enabled = config: {
      nx.homebrew.casks = [ "slack" ];
    };
  };
}
