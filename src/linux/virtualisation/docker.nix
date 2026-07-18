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
  name = "docker";

  group = "virtualisation";
  input = "linux";

  settings = {
    dataPath = "/var/lib/docker";
    storageDriver = "btrfs";
    addMainUserToGroup = true;
    additionalSettings = { };
  };

  module = {
    linux.system = config: {
      virtualisation.docker = {
        enable = true;
        storageDriver = self.settings.storageDriver;
        enableOnBoot = true;
        liveRestore = true;
        logDriver = "journald";

        daemon.settings = {
          data-root = self.settings.dataPath;
        }
        // self.settings.additionalSettings;
      };

      users.users =
        let
          deploymentMode = config.nx.global.deploymentMode;
          isServer = deploymentMode == "server" || deploymentMode == "managed";
        in
        lib.mkIf (self.settings.addMainUserToGroup && !isServer) {
          "${self.host.mainUser.username}" = {
            extraGroups = [ "docker" ];
          };
        };

      environment.systemPackages = with pkgs; [
        docker-compose
      ];

      environment.persistence."${self.persist}" = {
        directories = [
          self.settings.dataPath
        ];
      };
    };

    ifEnabled.linux.server.healthchecks = {
      enabled = config: {
        nx.linux.server.healthchecks.requireServicesUp = [ "docker.service" ];
      };
    };

    ifEnabled.linux.security.aide = {
      enabled = config: {
        nx.linux.security.aide.skipPaths = [
          "/opt/containerd"
          self.settings.dataPath
        ];
      };
    };
  };
}
