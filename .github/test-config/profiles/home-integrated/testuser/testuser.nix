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
    username = "testuser";

    fullname = "Test User";

    email = "testuser@example.com";

    addBaseGroup = true;

    modules = { };
  };
}
