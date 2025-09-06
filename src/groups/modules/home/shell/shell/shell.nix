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
  meta = {
    description = "Shell group module";
  };

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
