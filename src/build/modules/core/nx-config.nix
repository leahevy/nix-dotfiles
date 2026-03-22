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

  on = {
    standalone = config: {
      home.file.".config/nx/config.json" = {
        text = builtins.toJSON self.variables.nx.config;
      };
    };

    system = config: {
      environment.etc."nx/config.json" = {
        text = builtins.toJSON self.variables.nx.config;
        mode = "0444";
        user = "root";
        group = "root";
      };
    };
  };
}
