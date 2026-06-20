args@{
  lib,
  pkgs,
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

  submodules = {
    common = {
      proton = {
        mail = true;
        pass = true;
      };
    };
  };
}
