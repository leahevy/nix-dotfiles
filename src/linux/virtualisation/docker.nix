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

  assertions = [
    {
      assertion = !self.isModuleEnabled "virtualisation.podman";
      message = "docker and podman modules are mutually exclusive!";
    }
  ];

  module = {
    enabled = config: {
      nx.packages.extra = [ pkgs.docker ];

      nx.common.dev.agents.programs = {
        docker = {
          purpose = "building and running container images from a Dockerfile";
          requiresFiles = [ "Dockerfile" ];
          order = 90;
        };
        docker-compose = {
          purpose = "running multi-container projects from a compose file";
          requiresFiles = [
            "docker-compose.yml"
            "docker-compose.yaml"
            "compose.yml"
            "compose.yaml"
          ];
          order = 91;
        };
      };
    };

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

    ifEnabled.linux.power.ups = {
      enabled = config: {
        nx.linux.power.ups.onBatteryShutdownCommands = [
          {
            name = "docker-containers";
            command = "ids=$(${pkgs.docker}/bin/docker ps -q); if [ -n \"$ids\" ]; then ${pkgs.docker}/bin/docker stop --time 60 $ids; fi";
            killCommand = "ids=$(${pkgs.docker}/bin/docker ps -q); if [ -n \"$ids\" ]; then ${pkgs.docker}/bin/docker kill $ids; fi";
          }
        ];
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
