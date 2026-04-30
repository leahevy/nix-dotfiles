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
  name = "commandline";
  group = "core";
  input = "build";

  rawOptions = {
    nx.commandline = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
    };
  };
}
