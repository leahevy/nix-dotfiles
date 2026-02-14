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
  name = "proton";

  group = "proton";
  input = "common";
  namespace = "home";

  submodules = {
    common = {
      proton = {
        mail = true;
        pass = true;
      };
    };
  };
}
