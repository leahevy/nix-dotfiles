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
  name = "nx-config-standalone";
  group = "core";
  input = "build";
  namespace = "home";

  configuration =
    context@{ config, options, ... }:
    {
      home.file.".config/nx/config.json" = {
        text = builtins.toJSON self.variables.nx.config;
      };
    };
}
