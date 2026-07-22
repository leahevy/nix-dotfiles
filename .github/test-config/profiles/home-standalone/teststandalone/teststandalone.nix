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
    username = "teststandalone";

    fullname = "Test Standalone";

    email = "teststandalone@example.com";

    sopsPublicKey = "@SOPS_AGE_PUBLIC_KEY@";

    deploymentMode = "develop";

    addBaseGroup = true;

    modules = { };

    settings = {
      desktop = "gnome";
    };
  };
}
