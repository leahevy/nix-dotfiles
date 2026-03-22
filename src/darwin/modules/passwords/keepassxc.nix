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
  name = "keepassxc";

  group = "passwords";
  input = "darwin";

  submodules = {
    common = {
      passwords = {
        keepassxc = true;
      };
    };
  };

  on = {
    darwin.home = config: {
      nx.homebrew.casks = [ "keepassxc" ];
    };
  };
}
