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
  name = "postgresql";
  description = "Shared PostgreSQL instance";

  group = "server";
  input = "linux";

  options = {
    sharedBuffers = lib.mkOption {
      type = lib.types.str;
      default = "512MB";
      description = "Value for shared_buffers, ideally around 25% of available RAM.";
    };

    connectionSlots = lib.mkOption {
      type = lib.types.listOf lib.types.int;
      default = [ ];
      description = "Connection slot contributions per module, summed to produce max_connections.";
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf lib.types.anything;
      default = { };
      description = "Additional PostgreSQL configuration settings.";
    };
  };

  module = {
    linux.home = config: {
      home.shellAliases.psql = "sudo -u postgres psql";
    };

    linux.system =
      {
        config,
        sharedBuffers,
        connectionSlots,
        settings,
        ...
      }:
      {
        assertions = [
          {
            assertion = builtins.match "[0-9]+(kB|MB|GB|TB|PB)" sharedBuffers != null;
            message = "linux.server.postgresql: sharedBuffers must be a valid PostgreSQL memory string (e.g. 512MB, 2GB)!";
          }
        ];

        services.postgresql = {
          enable = true;
          settings = settings // {
            shared_buffers = sharedBuffers;
            max_connections = (builtins.foldl' (a: b: a + b) 0 connectionSlots) + 15;
          };
        };

        environment.persistence."${self.persist}" = {
          directories = [ config.services.postgresql.dataDir ];
        };
      };

    ifEnabled.linux.server.healthchecks = {
      enabled = config: {
        nx.linux.server.healthchecks.requireServicesUp = [ "postgresql.service" ];
      };
    };
  };
}
