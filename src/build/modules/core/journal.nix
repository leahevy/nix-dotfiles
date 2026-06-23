args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
{
  name = "journal";

  group = "core";
  input = "build";

  module = {
    system = config: {
      services.journald.extraConfig = ''
        ForwardToWall=no
      '';
    };
  };
}
