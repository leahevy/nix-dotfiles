args@{
  lib,
  pkgs,
  funcs,
  helpers,
  defs,
  self,
  ...
}:
let
  redisName = name: "redis" + lib.optionalString (name != "") ("-" + name);
  dataDir = name: "/var/lib/${redisName name}";
in
{
  name = "redis";
  description = "Shared Redis-compatible server with optional named instances";

  group = "server";
  input = "linux";

  options = {
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.valkey;
      description = "Redis-compatible server package used for all instances.";
    };

    instances = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            accessUsers = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "System users granted access to this instance's unix socket.";
            };
          };
        }
      );
      default = { };
      description = "Named Redis instances to run, keyed by instance name.";
    };
  };

  module = {
    linux.system =
      {
        config,
        package,
        instances,
        ...
      }:
      let
        allNames = lib.attrNames instances;
        dirEntry = name: {
          mode = "0700";
          user = redisName name;
          group = redisName name;
        };
      in
      {
        services.redis.package = package;
        services.redis.servers = lib.genAttrs allNames (name: {
          enable = true;
        });

        environment.persistence."${self.persist}" = {
          directories = map dataDir allNames;
        };

        systemd.tmpfiles.settings."nx-redis" = lib.mkMerge (
          map (
            name:
            {
              "${dataDir name}".d = dirEntry name;
            }
            // lib.optionalAttrs self.host.impermanence {
              "${self.persist}${dataDir name}".d = dirEntry name;
            }
          ) allNames
        );

        users.users = lib.mkMerge (
          lib.concatLists (
            lib.mapAttrsToList (
              name: inst: map (u: { ${u}.extraGroups = [ (redisName name) ]; }) inst.accessUsers
            ) instances
          )
        );
      };

    ifEnabled.linux.server.healthchecks.enabled = config: {
      nx.linux.server.healthchecks.requireServicesUp = map (name: "${redisName name}.service") (
        lib.attrNames config.nx.linux.server.redis.instances
      );
    };
  };
}
