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

  on = {
    darwin.home = config: {
      nx.homebrew.casks = [ "slack" ];
    };
  };
}
