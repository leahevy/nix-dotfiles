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
  name = "darwin";

  group = "core";
  input = "build";

  module = {
    darwin.home = config: {
      targets.darwin.copyApps.enable = false;
      targets.darwin.linkApps.enable = true;
    };
  };
}
