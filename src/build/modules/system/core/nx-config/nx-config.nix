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
  name = "nx-config";
  group = "core";
  input = "build";
  namespace = "system";

  configuration =
    context@{ config, options, ... }:
    {
      environment.etc."nx/config.json" = {
        text = builtins.toJSON self.variables.nx.config;
        mode = "0444";
        user = "root";
        group = "root";
      };
    };
}
