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
