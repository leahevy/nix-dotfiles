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
  config.user = {
    username = "testdarwin";

    fullname = "Test Darwin";

    email = "testdarwin@example.com";

    sopsPublicKey = "@SOPS_AGE_PUBLIC_KEY@";

    deploymentMode = "develop";

    addBaseGroup = true;

    modules = { };

    settings = {
      desktop = "yabai";
    };
  };
}
