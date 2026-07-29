{
  lib,
  pkgs,
  variables,
  helpers,
  defs,
  self,
  ...
}:
{
  config.host = {
    hostname = "testing";

    mainUser = "testuser-desktop";

    deploymentMode = "develop";

    addBaseGroup = true;

    sopsPublicKey = "@SOPS_AGE_PUBLIC_KEY@";

    modules = {
      linux = {
        networking = {
          tailscale = true;
        };
        virtualisation = {
          docker = true;
        };
        storage = {
          samba-utils = true;
          usb-access = true;
          borg-backup = {
            repository = {
              server = "example.com";
              port = 22;
              user = "example";
              path = "/backups";
            };
            schedule = "*-*-* 18:45:00";
            repoCheckMaxDuration = 900;
          };
        };
      };
    };

    settings = {
      system = {
        desktop = "gnome";
      };
    };

    impermanence = false;

    homeserverDomain = "example.com";
  };
}
