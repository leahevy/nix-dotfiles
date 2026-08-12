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
  name = "podman";

  group = "virtualisation";
  input = "linux";

  options = {
    enableDockerHost = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Set DOCKER_HOST to point to podman rootless socket";
    };
  };

  assertions = [
    {
      assertion = !self.isModuleEnabled "virtualisation.docker";
      message = "podman and docker modules are mutually exclusive!";
    }
  ];

  module = {
    linux.system = { config, enableDockerHost, ... }: {
      virtualisation.podman = {
        enable = true;
        package = pkgs.podman;
      };

      virtualisation.containers = {
        enable = true;
        containersConf.settings.containers = {
          log_driver = "journald";
          log_tag = lib.mkIf (!(helpers.isHeadless self)) "podman-container";
        };
      };

      environment.systemPackages = with pkgs; [
        podman
        docker
      ];

      environment.sessionVariables = lib.mkIf enableDockerHost {
        DOCKER_HOST = "unix:///run/user/${
          toString (config.users.users.${self.host.mainUser.username}.uid)
        }/podman/podman.sock";
      };
    };

    linux.enabled = config: {
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

      nx.linux.monitoring.journal-watcher.ignorePatterns = [
        {
          service = "podman.service";
          string = "Found left-over process.*in control group while starting unit\\. Ignoring\\.";
          user = true;
        }
        {
          service = "podman.service";
          string = "This usually indicates unclean termination.*";
          user = true;
        }
      ]
      ++ lib.optional (!(helpers.isHeadless self)) {
        tag = "podman-container";
        user = true;
      };
    };

    linux.home = config: {
      home.persistence."${self.persist}" = {
        directories = [
          ".local/share/containers"
        ];
      };
    };

    ifEnabled.linux.security.aide = {
      enabled = config: {
        nx.linux.security.aide.skipPaths = [
          ".local/share/containers"
        ];
      };
    };
  };
}
