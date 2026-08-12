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
  name = "docker-desktop";

  group = "dev";
  input = "darwin";

  module = {
    darwin.enabled = config: {
      nx.homebrew.casks = [ "docker-desktop" ];

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
  };
}
