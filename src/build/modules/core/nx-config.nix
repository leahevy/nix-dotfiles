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
      deploymentMode = lib.mkOption {
        type = lib.types.enum [
          "managed"
          "server"
          "local"
          "develop"
        ];
        description = "Deployment mode for this machine";
      };
      isVMHost = lib.mkOption {
        type = lib.types.bool;
        description = "Whether this host is configured to run VMs";
      };
      minEnabledModules = lib.mkOption {
        type = lib.types.int;
        default = 10000;
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
            default = "last";
            description = "Commit verification level for nxcore repository";
          };
          nxconfig = lib.mkOption {
            type = lib.types.enum [
              "all"
              "last"
              "none"
            ];
            default = "last";
            description = "Commit verification level for nxconfig repository";
          };
        };
      };
    };
  };

  module = {
    enabled = config: {
      nx.global = self.variables.nx.config // {
        deploymentMode = helpers.resolveFromHostOrUser config [ "deploymentMode" ] "develop";
        isVMHost = helpers.resolveFromHostOrUser config [ "isVMHost" ] false;
      };
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
