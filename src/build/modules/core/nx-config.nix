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

  rawOptions = {
    nx.global = {
      minEnabledModules = lib.mkOption {
        type = lib.types.int;
        description = "Minimum number of modules that must be enabled to ensure configuration integrity";
      };
      security = {
        commitVerification = {
          nxcore = lib.mkOption {
            type = lib.types.enum [
              "all"
              "last"
              "none"
            ];
            description = "Commit verification level for nxcore repository";
          };
          nxconfig = lib.mkOption {
            type = lib.types.enum [
              "all"
              "last"
              "none"
            ];
            description = "Commit verification level for nxconfig repository";
          };
        };
      };
    };
  };

  on = {
    enabled = config: {
      nx.global = self.variables.nx.config;
    };

    standalone = config: {
      home.file.".config/nx/config.json" = {
        text = builtins.toJSON config.nx.global;
      };
    };

    system = config: {
      environment.etc."nx/config.json" = {
        text = builtins.toJSON config.nx.global;
        mode = "0444";
        user = "root";
        group = "root";
      };
    };
  };
}
