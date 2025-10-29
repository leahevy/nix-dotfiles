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
  name = "docker";

  group = "virtualisation";
  input = "linux";
  namespace = "system";

  settings = {
    dataPath = "/var/lib/docker";
    storageDriver = "btrfs";
    addMainUserToGroup = true;
    additionalSettings = { };
  };

  configuration =
    context@{ config, options, ... }:
    {
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

      users.users = lib.mkIf self.settings.addMainUserToGroup {
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
}
