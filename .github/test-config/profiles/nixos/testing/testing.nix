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

    mainUser = "testuser";

    deploymentMode = "develop";

    addBaseGroup = true;

    sopsPublicKey = "@SOPS_AGE_PUBLIC_KEY@";

    modules = { };

    settings = {
      system = {
        desktop = "gnome";
      };
    };

    impermanence = false;
  };
}
