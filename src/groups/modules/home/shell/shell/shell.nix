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
  name = "shell";
  description = "Shell group module";

  group = "shell";
  input = "groups";
  namespace = "home";

  submodules = {
    common = {
      shell = {
        bash = true;
        zsh = true;
        fish = true;
        session = true;
      };
    };
  };
}
