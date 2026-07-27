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
      };
    };

    settings = {
      system = {
        desktop = "gnome";
      };
    };

    impermanence = false;
  };
}
