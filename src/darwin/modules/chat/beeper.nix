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
  name = "beeper";

  group = "chat";
  input = "darwin";

  on = {
    darwin.enabled = config: {
      nx.homebrew.casks = [ "beeper" ];
    };
  };
}
