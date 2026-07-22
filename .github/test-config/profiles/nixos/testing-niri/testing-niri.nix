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
    hostname = "testing-niri";

    mainUser = "testuser";

    deploymentMode = "develop";

    addBaseGroup = true;

    sopsPublicKey = "@SOPS_AGE_PUBLIC_KEY@";

    displays = {
      main = "Virtual-1";
    };

    location = {
      latitude = 0.0;
      longitude = 0.0;
    };

    modules = { };

    settings = {
      system = {
        desktop = "niri";
      };
    };

    impermanence = true;
  };
}
