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
    hostname = "testing-pi";

    mainUser = "testuser";

    deploymentMode = "develop";

    addBaseGroup = true;

    sopsPublicKey = "@SOPS_AGE_PUBLIC_KEY@";

    hardware = {
      board = "pi5";
    };

    modules = { };

    settings = { };

    impermanence = true;
  };
}
