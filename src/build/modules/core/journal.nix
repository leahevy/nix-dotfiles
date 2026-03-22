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
  name = "journal";

  group = "core";
  input = "build";

  on = {
    system = config: {
      services.journald.extraConfig = ''
        ForwardToWall=no
      '';
    };
  };
}
